--[[
	服务器启动服务中心
]]
local skynet = require "skynet"
local dbconf = require "dbconf"
local svrAddrMgr = require "svrAddrMgr"
local svrConf = require "svrConf"
local initDBConf = require "initDBConf"
local serviceCenterBase = require("serviceCenterBase2")
local serverStartCenter = class("serverStartCenter", serviceCenterBase)

-- 构造
function serverStartCenter:ctor()
	serverStartCenter.super.ctor(self)
    
	-- 全局服存活列表、一致性哈希
	self.aliveGb = {}
	self.hashGb = require("conhash").new()
end

-- 初始化
function serverStartCenter:init()
	gLog.i("==serverStartCenter:init begin==")

	-- 服务器启动服务管理
    self.serverStartMgr = require("serverStartMgr").new()

    gLog.i("==serverStartCenter:init end==")
end

-- 获取频道
function serverStartCenter:getChannel()
	return self.serverStartMgr:getChannel()
end

-- 获取是否所有服均已初始化好
function serverStartCenter:getIsOk()
	return self.serverStartMgr:getIsOk()
end

-- 完成初始化
function serverStartCenter:finishInit(svrName, address)
	self.serverStartMgr:finishInit(svrName, address)
end

-- 停止所有服务
function serverStartCenter:stop()
	gLog.i("serverStartCenter:stop")
	return self.serverStartMgr:stop()
end

-- 收到信号停止所有服务
function serverStartCenter:stopSignal()
	gLog.i("serverStartCenter:stopSignal")
	self:stop()
end

-- [已废弃,走redis频道订阅]其它服通知过来, 设置玩家当前所在王国KID
--function serverStartCenter:setKidOfUid(uid, kid, flag)
--	gLog.i("serverStartCenter:setKidOfUid", uid, kid, flag)
--	local playerDataLib = require("playerDataLib")
--	for i = 1, playerDataLib.serviceNum do
--		skynet.send(playerDataLib:getAddress(dbconf.globalnodeid, i), "lua", "setKidOfUid", uid, kid, flag)
--	end
--end

-- 加载服务器配置
function serverStartCenter:reloadConf(nodeid)
	gLog.i("serverStartCenter:reloadConf =", nodeid)
	-- 旧的全局服列表
	local globalOld = {}
	local ret = initDBConf:getClusterConf()
	for k, v in pairs(ret) do
		if v.type == 2 then --cluster集群类型: 1登陆服 2全局服 3游戏服
			globalOld[v.nodeid] = true
		end
	end
	-- 刷新服务器配置
	initDBConf:set(true)
	-- 新的全局服列表
	local globalNew = {}
	local ret = initDBConf:getClusterConf()
	for k, v in pairs(ret) do
		if v.type == 2 then --cluster集群类型: 1登陆服 2全局服 3游戏服
			globalNew[v.nodeid] = true
		end
	end
	-- 若全局服配置变更, 需要立即执行数据落地, 此时最好是维护一下, 不然由于存库/读库存在时序问题, 可能会导致一些数据问题
	if not table.equal(globalOld, globalNew) then
		gLog.e("serverStartCenter:reloadConf saveNow!")
		local playerDataLib = require("playerDataLib")
		for i=1,playerDataLib.serviceNum,1 do
			playerDataLib:saveNow(dbconf.globalnodeid, i)
		end
	end
	-- 若有全局服节点被移除, 需要更新一致性哈希
	local globalConf = initDBConf:getGlobalConf()
	for nodeid,_ in pairs(self.aliveGb) do
		if not globalConf[nodeid] then
			self.aliveGb[nodeid] = nil
			self.hashGb:deletenode(tostring(nodeid))
		end
	end
	gLog.i("serverStartCenter:reloadConf end=", nodeid)
end

-- 全局服存活检测
function serverStartCenter:checkAliveGb()
	local globalConf = initDBConf:getGlobalConf()
	for k,v in pairs(globalConf) do
		local callOk, ok = pcall(function()
			if v.nodeid == dbconf.globalnodeid then
				return self:getIsOk()
			end
			local startSvr = svrConf:getSvrProxyGlobal(v.nodeid, svrAddrMgr.startSvr)
			return skynet.call(startSvr, "lua", "getIsOk")
		end)
		--gLog.d("serverStartCenter:checkAliveGb=", v.nodeid, callOk, ok)
		if callOk and ok then
			if not self.aliveGb[v.nodeid] then
				self.aliveGb[v.nodeid] = v.nodeid
				self.hashGb:addnode(tostring(v.nodeid), 1024)
			end
		else
			if self.aliveGb[v.nodeid] then
				self.aliveGb[v.nodeid] = nil
				self.hashGb:deletenode(tostring(v.nodeid))
			end
		end
	end
	-- 间隔13s
	skynet.timeout(1300, function()
		self:checkAliveGb()
	end)
end

-- 业务ID映射全局服节点
function serverStartCenter:hashNodeidGb(id)
	return tonumber(self.hashGb:lookup(tostring(id)))
end

return serverStartCenter
