---@diagnostic disable: code-indent
--[[
	账号辅助类
]]
local skynet = require("skynet")
local mysql = require("mysql")
local dbconf = require("dbconf")
local svrConf = require("svrConf")
local svrFunc = require("svrFunc")
local initDBConf = require("initDBConf")
local svrAddrMgr = require("svrAddrMgr")
local agentLib = require("agentLib")
local playerDataLib = require("playerDataLib")
local accountHelper = class("accountHelper")

function accountHelper:ctor()
	-- 导量方式
	self.importStyle = gImportStyle.BALANCE
	-- 存活区服/王国列表
	self.aliveList = {}
	-- 区服/王国列表
	self.svrList = {}
	self.maxKid = nil
	self.defaultKid = nil
	self.hash = require("conhash").new()
end

-- 初始化
function accountHelper:init()
	gLog.i("accountHelper:init")
	-- 更新创建新号的存活区服王国列表
	self:updateNewUserKid()
end

-- 更新创建新号的存活区服王国列表
function accountHelper:updateNewUserKid()
	local svrList, maxKid = {}, nil
	local kingdomConf = initDBConf:getKingdomConf()
	--gLog.dump(kingdomConf, "accountHelper:updateNewUserKid kingdomConf=")
    for k,v in pairs(kingdomConf) do
    	if v.isNew == gServerNew.NEW then
			svrList[v.nodeid] = v
			if not maxKid or v.kid > maxKid then
				maxKid = v.kid
			end
        end
    end
    -- gLog.dump(svrList, "accountHelper:updateNewUserKid svrList=")
	self.svrList = svrList
	self.maxKid = maxKid
	self.defaultKid = nil

	-- 若某个区服/王国删除, 则从一致性哈希中移除
	for nodeid,v in pairs(self.aliveList) do
		if not self.svrList[nodeid] and self.aliveList[nodeid] then
			for _,kid in ipairs(self.aliveList[nodeid]) do
				self.hash:deletenode(tostring(kid))
			end
			self.aliveList[nodeid] = nil
		end
	end
    -- gLog.dump(self.aliveList, "accountHelper:updateNewUserKid aliveList=")
end

function accountHelper:registerGate(nodeid)
	if not self.aliveList[nodeid] and self.svrList[nodeid] then
		local kidList = svrConf:getKingdomIDListByNodeID(nodeid)
		if next(kidList) then
			self.aliveList[nodeid] = kidList
			for _,kid in ipairs(self.aliveList[nodeid]) do
				self.hash:addnode(tostring(kid), 1024)
			end
			-- gLog.d("accountHelper:registerGate aliveList=", table2string(self.aliveList), "hash count=", self.hash:count())
		end
	end
end

function accountHelper:unregisterGate(nodeid)
	if self.aliveList[nodeid] then
		for _,kid in ipairs(self.aliveList[nodeid]) do
			self.hash:deletenode(tostring(kid))
		end
		self.aliveList[nodeid] = nil
		--gLog.d("accountHelper:unregisterGate aliveList=", table2string(self.aliveList), "hash count=", self.hash:count())
	end
end

function accountHelper:callDbSvr(...)
	return skynet.call(svrAddrMgr.getSvr(svrAddrMgr.gameDBSvr), "lua", ...)
end

-- 根据uid查询账号信息
function accountHelper:queryAccountByUid(uid)
	if dbconf.dbtype == "mongodb" then
		local ret = self:callDbSvr("find", uid, "account")
		-- gLog.dump(ret, "accountHelper:queryAccountByUid ret=")
		if ret and not ret.err then
			if ret[1] then
				return true, ret[1].uid, ret[1].kid, ret[1].status
			end
		end
		return false
	elseif dbconf.dbtype == "mysql" then
        local strSql = string.format("select `_id`, `user`, `kid`, `status` from `account` where `_id` = %d", mysql.quote_sql_str(uid))
		-- gLog.d("accountHelper:queryAccountByUid strSql=", strSql)
		local ret = self:callDbSvr("execute", strSql)
		-- gLog.dump(ret, "accountHelper:queryAccountByUid ret=")
		if ret and not ret.err and ret[1] then
			return true, ret[1].user, ret[1].kid, ret[1].status
		end
	else
		assert(false, "dbconf.dbtype error"..tostring(dbconf.dbtype))
	end
end

-- 根据user查询账号信息
function accountHelper:queryAccountByUser(user)
	if dbconf.dbtype == "mongodb" then
		local ret = self:callDbSvr("find", nil, "account", {user = user})
		-- gLog.dump(ret, "accountHelper:queryAccountByUser ret=")
		if ret and not ret.err then
			if ret[1] then
				return true, ret[1]._id, ret[1].kid, ret[1].status
			end
		end
		return true
	elseif dbconf.dbtype == "mysql" then
		local strSql = string.format("select `uid`, `kid`, `status` from `account` where `user` = %s", mysql.quote_sql_str(user))
		local ret = self:callDbSvr("execute", strSql)
		-- gLog.dump(ret, "accountHelper:queryAccountByUser ret=")
		if ret and not ret.err then
			if ret[1] then
				return true, ret[1]._id, ret[1].kid, ret[1].status
			end
			return true
		end
		return false
	else
		assert(false, "dbconf.dbtype error"..tostring(dbconf.dbtype))
	end
	
end

-- 根据user获取账号信息, 若没有找到则生成一个
function accountHelper:getAccountInfo(user, addr, plateform)
	gLog.d("accountHelper:getAccountInfo user=", user, "addr=", addr, "plateform=", plateform)
	local ok, uid, kid, status = self:queryAccountByUser(user)
	if not ok then
		gLog.w("accountHelper:getAccountInfo error1", user, ok, uid, kid, status)
		return
	end
	gLog.i("accountHelper:getAccountInfo do1=", user, addr, plateform, "uid=", uid, kid, status)
	-- 无账号则注册新账号
	local isNewUser = false
	if not uid then
		-- 从存活王国中创建一个新账号
		if not next(self.aliveList) then
			gLog.w("accountHelper:getAccountInfo error2", user, uid, kid, status, table2string(self.aliveList))
			return
		end
		-- 以ip白名单登录的新账号, 默认分配到最大的新王国
		local whiteConf = initDBConf:getIpWhiteListConf(dbconf.loginnodeid)
		if whiteConf and whiteConf.status == gIpWhiteListStatus.OPEN and whiteConf.ipList then
			local ips = svrFunc.split(addr, ":")
			if ips and ips[1] and string.find(whiteConf.ipList, ips[1]) then
				kid = self.maxKid
				gLog.i("accountHelper:getAccountInfo do3=", user, "kid=", kid)
			end
		end
		-- 根据导量策略分配新王国
		if not kid then
			-- 单服导量
			if self.importStyle == gImportStyle.ONE then
				kid = self:generateKid()
				gLog.i("accountHelper:getAccountInfo do4=", user, "kid=", kid)
			end
			-- 多服导量
			if not kid then
				kid = tonumber(self.hash:lookup(user)) -- 一致性哈希
				gLog.i("accountHelper:getAccountInfo do5=", user, "kid=", kid)
			end
		end
		--
		if not kid or not self.aliveList[kid] then
			gLog.w("accountHelper:getAccountInfo error6", user, uid, kid, status)
			return
		end
		-- 创建新账号
		isNewUser = true
		status = gAccountStatus.NORMAL
		uid = self:createAccount(user, kid, status)
	else
		-- 检查user映射区服/王国是否变化, 变化则自动迁服, 若非万人同服, 此逻辑去除即可
		local newkid = tonumber(self.hash:lookup(tostring(user)))
		gLog.i("accountHelper:getAccountInfo do6 user=", user, kid, newkid)
		if newkid and newkid ~= kid then
			-- 先新服迁入(一般无数据落地、清理redis)
			local ok1 = xpcall(function()
				agentLib:call(newkid, "migrateIn", uid, nil, newkid)
			end, svrFunc.exception)
			-- 再旧服迁出(数据落地、清理redis)
			local ok2 = xpcall(function()
				agentLib:call(kid, "migrateOut", uid, nil, newkid)
			end, svrFunc.exception)
			-- 设置玩家当前所在王国KID
			playerDataLib:setKidOfUid(uid, newkid, 0)
			gLog.i("accountHelper:getAccountInfo do7 user migrate=", user, kid, newkid, ok1, ok2)
			kid = newkid
		end
		--
		if not kid or not self.aliveList[kid] then
			gLog.w("accountHelper:getAccountInfo error7", user, uid, kid, status)
			return
		end
	end
	--
	if not uid then
		gLog.w("accountHelper:getAccountInfo error8", user, uid, kid, status)
		return
	end
	-- 获取game服节点的gate相关配置
	local kingdomConf = svrConf:getKingdomConfByKid(kid)
	if not kingdomConf then
		gLog.w("accountHelper:getAccountInfo error9", user, uid, kid, status)
		return
	end
	local gateConf = svrConf:gateConfGame(kingdomConf.nodeid)
	if not gateConf then
		gLog.w("accountHelper:getAccountInfo error10", user, uid, kid, status)
		return
	end
	--
	return {
		uid = uid,
		kid = kid,
		status = status,
		isNewUser = isNewUser,
		gatenodeid = gateConf.nodeid,
		gateip = (gateConf.web ~= "127.0.0.1" and gateConf.web ~= "localhost") and gateConf.web or gateConf.address,
		gateport = gateConf.port,
		servername = svrAddrMgr.getSvrName(svrAddrMgr.gateSvr, nil, gateConf.nodeid),
	}
end

-- 根据数据库配置默认给玩家分配一个王国id
function accountHelper:generateKid()
	if not self.defaultKid then
		local ret = nil
		if dbconf.dbtype == "mongodb" then
			ret = self:callDbSvr("find", 1, "conf_general")
		elseif dbconf.dbtype == "mysql" then
			local strSql = string.format("select defaultKid from conf_general")
			ret = self:callDbSvr("execute", strSql)
		else
			assert(false, "dbconf.dbtype error"..tostring(dbconf.dbtype))
		end
		if ret and ret[1] and (ret[1].defaultKid or 0) > 0 then
			gLog.i("accountHelper:generateKid", ret[1].defaultKid or 0)
			self.defaultKid = ret[1].defaultKid
		else
			self.defaultKid = 0
		end
	end
	if self.defaultKid > 0 then
		return self.defaultKid
	end
end

--创建一个新账号
function accountHelper:createAccount(user, kid, status)
	if dbconf.dbtype == "mongodb" then
		local ret = self:callDbSvr("findAndModify", "account_seq", {
			query = {["_id"] = "account_seq" },
			update = {["$inc"] = {nextid = 1}},
			new = true,
		})
		-- gLog.dump(ret, "accountHelper:createAccount findAndModify ret=")
		assert((ret and not ret.err and ret.value and ret.value.nextid), "accountHelper:createAccount error")
		local uid = ret.value.nextid
		local ret = self:callDbSvr("safe_insert", uid, "account", nil, {
			_id = uid,
			user = user,
			kid = kid,
			status = status,
		})
		assert((ret == true), "accountHelper:createAccount error, ret="..tostring(ret))
		return uid
	elseif dbconf.dbtype == "mysql" then
		local strSql = string.format("insert into account(user,kid,status) values (%s,%d,%d)", mysql.quote_sql_str(user), kid, status)
		local ret = self:callDbSvr("execute", strSql)
		--gLog.dump(ret, "accountHelper:createAccount ret=")
		if ret and ret.insert_id then
			return ret.insert_id
		end
	else
		assert(false, "dbconf.dbtype error"..tostring(dbconf.dbtype))
	end
end

-- 设置玩家的封号状态
function accountHelper:setSealAccountStatus(uid, status)
	if dbconf.dbtype == "mongodb" then
		local ret = self:callDbSvr("safe_update", uid, "account", nil, {status = status})
		if ret and not ret.err then
			return true
		end
		return false
	elseif dbconf.dbtype == "mysql" then
		local strSql = string.format("UPDATE `account` SET `status`='%s' WHERE uid = %s", tostring(status), tostring(uid))
		gLog.i("accountHelper.setSealAccountStatus strSql=", strSql)
		local ret = self:callDbSvr("execute", strSql)
		if ret and not ret.err then
			return true
		end
		return false
	else
		assert(false, "dbconf.dbtype error"..tostring(dbconf.dbtype))
	end
end

-- 设置导量方式
function accountHelper:setImportStyle(mStyle)
	if mStyle and (mStyle == gImportStyle.BALANCE or mStyle == gImportStyle.ONE) then
		self.importStyle = mStyle
		gLog.i("accountHelper:setImportStyle=", self.importStyle)
	end
end

return accountHelper
