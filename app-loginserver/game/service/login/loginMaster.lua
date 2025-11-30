--[[
  登陆服务中心父服务
]]
local skynet = require("skynet.manager")
local socket = require("skynet.socket")
local crypt = require("skynet.crypt")
local svrConf = require("svrConf")
local svrFunc = require("svrFunc")
local svrAddrMgr = require("svrAddrMgr")
local serviceCenterBase = require("serviceCenterBase2")
local loginMaster = class("loginMaster", serviceCenterBase)

-- 构造
function loginMaster:ctor()
	loginMaster.super.ctor(self)
	-- 存活的游戏网关列表
	self.aliveList = {}
	-- 在线玩家
	self.userOnline = {}
	-- 子服务
	self.slave = {}
end

-- 初始化
function loginMaster:init(slave)
	gLog.i("== loginMaster:init begin ==")
	self.slave = slave or {}
	-- 订阅服务器启动服务频道
	self:subscribeStartService()
	gLog.i("== loginMaster:init end ==")
end

-- 读
function loginMaster:readline(fd)
	local v = socket.readline(fd)
	if v then
		return v
	else
		gLog.i(string.format("loginMaster:readline error: socket (fd = %d) closed", fd))
		error("socket error")
	end
end

-- 写
function loginMaster:write(fd, text)
	local v = socket.write(fd, text)
	if v then
		return v
	else
		gLog.i(string.format("loginMaster:write error: socket (fd = %d) closed", fd))
		error("socket error")
	end
end

-- 游戏服网关OPEN后向登录服注册网关服务代理
function loginMaster:registerGate(nodeid, svrName)
	--gLog.i("loginMaster:registerGate", nodeid, svrName)
	if nodeid then
		if not self.aliveList[nodeid] then
			svrName = svrAddrMgr.getSvrName(svrAddrMgr.gateSvr, nil, nodeid)
			self.aliveList[nodeid] = svrConf:getSvrProxyGame2(nodeid, svrName)
			for _,addr in pairs(self.slave) do
				skynet.send(addr, "lua", "registerGate", nodeid)
			end
			gLog.i("loginMaster:registerGate", nodeid, svrName)
		end
		return true
	end
	return false
end

-- 游戏服网关CLOSE后向登录服取消注册网关服务代理
function loginMaster:unregisterGate(nodeid)
	if nodeid then
		gLog.i("loginMaster:unregisterGate", nodeid)
		if self.aliveList[nodeid] then
			self.aliveList[nodeid] = nil
			for _,addr in pairs(self.slave) do
				skynet.send(addr, "lua", "unregisterGate", nodeid)
			end
			gLog.dump(self.aliveList, "loginMaster:unregisterGate")
		end
		return true
	end
	return false
end

-- 接收处理客户端sokect请求
function loginMaster:accept(address, fd, addr)
	gLog.i("loginMaster:accept enter =", address, fd, addr)
	local time = svrFunc.systemTime()

	-- 调用子服务, 认证
	local ok, secret, uInfo, version, plateform, model, user = pcall(skynet.call, address, "lua", "auth", fd, addr)
	if not ok then
		self:write(fd, "401 Unauthorized\n")
		error("401 Unauthorized")
	end
	gLog.dump(uInfo, "loginMaster:accept uInfo=", 10)

	-- 再次检测玩家信息
	if not uInfo or not uInfo.gatenodeid or not uInfo.kid or not uInfo.uid then
		self:write(fd, "401 Unauthorized\n")
		error("401 Unauthorized")
	end

	socket.start(fd)

	-- 检测封号状态
	if (uInfo.status or 0) ~= gAccountStatus.NORMAL then
		self:write(fd, "502 User Status Invalid\n")
		error(string.format("502 User Status Invalid, uid = %d", tostring(uInfo.uid)))
	end

	-- 白名单开启时, 必须通过ip限制才能登陆
	local ipWhiteConf = svrConf:getIpWhiteListConfGame(uInfo.kid)
	gLog.dump(ipWhiteConf, "loginMaster:accept ipWhiteConf =", 10)
	if ipWhiteConf and ipWhiteConf.status == gIpWhiteListStatus.OPEN then
		local arrIp = svrFunc.split(addr, ":")
		local clientIp = arrIp[1]
		gLog.d("loginMaster:accept clientIp=", clientIp, "ipList=", ipWhiteConf.ipList)
		if not clientIp or not string.find(ipWhiteConf.ipList, clientIp) then
			self:write(fd, "501 IP Not In White List\n")
			error("501 IP Not In White List")
		end
	end

	-- 再次检查网关是否存在
	local gateAddress = self.aliveList[uInfo.gatenodeid]
	if not gateAddress then
		self:write(fd, "501 Not Exist Server\n")
		error("501 Not Exist Server")
	end

	-- 检测服务器状态是否维护中
	local kingdomConf = svrConf:getKingdomConfByKid(uInfo.kid)
	if not (kingdomConf and tonumber(kingdomConf.status) == gServerStatus.NORMAL) then
		gLog.dump(kingdomConf, "loginMaster:accept kingdomConf=")
		self:write(fd, "501 kingdom status is not normal\n")
		error("kingdom status is not normal")
	end

	--只能一个客户端登陆(disallow multilogin), 如果已经登陆, 则先踢掉
	local uid = uInfo.uid
	local onlineInfo = self.userOnline[uid]
	if onlineInfo then
		gLog.w("loginMaster:accept afk user, uid = ", uid, "kid =", onlineInfo.kid, "subid =", onlineInfo.subid, "address =", onlineInfo.address)
		xpcall(function ()
			skynet.call(onlineInfo.address, "lua", "afk", uid, onlineInfo.subid, 1)
		end, svrFunc.exception)
		self.userOnline[uid] = nil
	end

	--调用游戏服, 登陆
	local ok, subid, isInit = xpcall(function ()
		gLog.d("loginMaster:accept call gate login=", uid, uInfo.kid, uInfo.isNewUser)
		return skynet.call(gateAddress, "lua", "login", uid, uInfo.kid, uInfo.isNewUser, secret, version, plateform, model, addr)
	end, svrFunc.exception)
	if not ok then
		self:write(fd,  "403 forbidden\n")
		error("forbidden")
	end
	if type(subid) ~= "number" then
		gLog.e("loginMaster:accept no subid, uid = ", uid, "svrName =", uInfo.servername, "subid =", subid)
		self:write(fd,  "500 server error\n")
		error("server error")
	end

	--登录成功, 记录登录信息
	self.userOnline[uid] = {
		svrName = uInfo.servername,
		address = gateAddress,
		uid = uid,
		subid = subid,
		kid = uInfo.kid,
	}
	gLog.dump(self.userOnline[uid], "loginMaster:accept login userOnline uid="..uid)

	-- 登陆成功, 返回网关数据
	local b64kid = crypt.base64encode(uInfo.kid)
	local b64gatenodeid = crypt.base64encode(uInfo.gatenodeid)
	local b64gateip = crypt.base64encode(uInfo.gateip)
	local b64gateport = crypt.base64encode(uInfo.gateport)
	local b64subid = crypt.base64encode(subid)
	local b64uid = crypt.base64encode(uid)
	local b64isInit = crypt.base64encode(isInit and 1 or 0)

	local msg = string.format("%s@%s@%s@%s@%s@%s@%s", b64kid, b64gatenodeid, b64gateip, b64gateport, b64subid, b64uid, b64isInit)
	gLog.d("=loginMaster:accept msg==", msg)
	self:write(fd,  "200 "..crypt.base64encode(msg).."\n")

	local costTime = svrFunc.systemTime() - time
	gLog.i("loginMaster:accept success end, uid=", uid, "subid=", subid, "servername=", uInfo.servername, "isInit=", isInit, "costTime=", costTime)
end

-- 登出(游戏服gate调用)
function loginMaster:logout(uid, subid)
	gLog.i("loginMaster:logout =", uid, subid)
	local u = self.userOnline[uid]
	if u then
		gLog.i("loginMaster:logout ok", uid, subid, "svrName=", u.svrName, u.subid)
		self.userOnline[uid] = nil
	end
	--gLog.dump(self.userOnline, "loginMaster:logout self.userOnline=")
end

-- 获取某个王国的服务器状态
function loginMaster:getKingdomSvrState(kid)
	local kingdomConf = svrConf:getKingdomConfByKid(kid)
	local status = kingdomConf and kingdomConf.status
	gLog.i("loginMaster:getKingdomSvrState", kid, status)
	return status
end

-- 加载服务器配置
function loginMaster:reloadConf(nodeid)
	gLog.i("loginMaster:reloadConf", nodeid)
	for _,addr in pairs(self.slave) do
		skynet.send(addr, "lua", "reloadConf", nodeid)
	end
end

return loginMaster

