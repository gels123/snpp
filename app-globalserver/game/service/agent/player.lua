--[[
	玩家上层逻辑
--]]
local skynet = require("skynet")
local socketdriver = require("skynet.socketdriver")
local netpack = require ("skynet.netpack")
local dbconf = require("dbconf")
local svrAddrMgr = require("svrAddrMgr")
local svrFunc = require("svrFunc")
local multiProc = require("multiProc")
local json = require("json")
local playerDataLib = require("playerDataLib")
local clientCmd = require("clientCmd")
local agentCenter = require("agentCenter"):shareInstance()
local player = class("player")

-- 注册客户端指令
do
	require "loginCmd"
	require "chatCmd"
	require "tradeCmd"
end

-- 构造
function player:ctor(uid)
	self.uid = assert(uid)  -- 玩家ID
	self.subid = nil        -- 玩家subid
	self.fd = nil           -- 套接字fd
	self.online = nil   	-- 是否在线
	self.sn = 0				-- 请求sessionid

	self.modules = {}		-- 模块

    self.msgNotify = {}   	-- 推送消息队列

    self.checkinTime = nil 	-- checkin时间
    self.afkTime = nil 		-- afk时间
end

-- 获取王国ID
function player:getKid()
	return agentCenter.kid
end

-- 获取玩家ID
function player:getUid()
    return self.uid
end

-- 获取玩家subid
function player:getSubid()
    return self.subid
end

-- 获取套接字fd
function player:getFd()
    return self.fd
end

-- 是否在线
function player:getOnline()
	return self.online
end

-- 获取模块
function player:getModule(moduleName)
	--gLog.d("player:getModule", self:getUid(), moduleName)
	if not self.modules[moduleName] then
		self.modules[moduleName] = require(moduleName).new(self.uid)
	end
	assert(self.modules[moduleName], "player:getModule error: module not exist!")
	-- 若已初始化, 则校验数据
	if self.modules[moduleName]:isInit() then
		self.modules[moduleName]:check()
	end
	return self.modules[moduleName]
end

-- 玩家登录
function player:login(uid, subid)
	local sq = agentCenter:getSq(uid)
	return sq(function()
		gLog.i("==player:login begin==", uid, subid)
		--
		self.sn = 0
		self.uid = uid
		self.subid = subid or self.subid
		self.afkTime = nil
		self.msgNotify = {}
		-- init模块
		self:initModule()
		gLog.i("==player:login end==", uid, subid)
		return true
	end)
end

-- 玩家切入
function player:checkin(subid)
	local sq = agentCenter:getSq(self.uid)
	return sq(function()
		gLog.i("==player:checkin begin==", self.uid, self.subid, "subid=", subid)
		--
		self.subid = subid
		-- 客户端是否需要重新初始化
		local isInit = not (svrFunc.systemTime() < (self.afkTime or 0))
		-- 设置在线
		self.online = true
		-- 设置checkin时间、afk时间
		self.checkinTime = svrFunc.systemTime()
		self.afkTime = 0
		-- checkin模块
		self:checkinModule()
		gLog.i("==player:checkin end==", self.uid, self.subid, isInit)
		return true, isInit
	end)
end

-- 玩家暂离, agent服务还在
function player:afk(flag)
	local sq = agentCenter:getSq(self.uid)
	return sq(function()
		gLog.i("==player:afk begin==", self.uid, self.subid, flag)
		-- 推送登出
		if self.online and flag then
			self:notifyMsg("notifyLogout", {flag = flag or 0,})
		end
		-- 移除fd关联
		agentCenter.playerMgr:setFdMap(self.fd, nil)
		-- 设置套接字fd
		self.fd = nil
		-- 设置离线
		self.online = false
		-- 设置afk时间
		if self.afkTime == 0 then
			self.afkTime = svrFunc.systemTime() + 30
		end
		-- afk模块
		self:afkModule()
		-- 回收内存
		 skynet.send(skynet.self(),"debug", "GC")
		gLog.i("==player:afk end==", self.uid, self.subid, flag)
		return true
	end)
end

-- 玩家登出
function player:logout(flag)
	local sq = agentCenter:getSq(self.uid)
	return sq(function()
		gLog.i("==player:logout begin==", self.uid, self.subid, "flag=", flag)
		-- 设置离线
		self.online = false
		-- 设置afk时间
		self.afkTime = nil
		-- logout模块
		self:logoutModule()
		-- 回收内存
		skynet.send(skynet.self(),"debug", "GC")
		gLog.i("==player:logout end==", self.uid, self.subid)
		return true
	end)
end

-- init模块
function player:initModule()
	gLog.i("==player:initModule begin", self.uid)
	local time1 = skynet.time()
	-- 并行执行查库任务(mysql会是性能热点), 需优先执行的模块放上面
	local mp = multiProc.new()
	-- 登录信息模块、聊天信息模块
	mp:fork(function()
		local loginCtrl = self:getModule(gModuleDef.loginModule)
		loginCtrl:init()
		local chatCtrl = self:getModule(gModuleDef.chatModule)
		chatCtrl:init()
	end)
	-- 拍卖行模块
	mp:fork(function()
		local tradeCtrl = self:getModule(gModuleDef.tradeModule)
		tradeCtrl:init()
	end)
	-- 等待所有任务执行结束
	mp:wait()
	local time2 = skynet.time()
	gLog.i("==player:initModule end", self.uid, "time=", time2-time1)
end

-- checkin模块
function player:checkinModule()
	gLog.i("==player:checkinModule begin", self.uid)
	-- 登录信息
	local loginCtrl = self:getModule(gModuleDef.loginModule)
	loginCtrl:checkin()
	gLog.i("==player:checkinModule end", self.uid)
end

-- afk模块
function player:afkModule()
	gLog.i("==player:afkModule begin", self.uid)
	-- 登录信息
	local loginCtrl = self:getModule(gModuleDef.loginModule)
	loginCtrl:afk()
	gLog.i("==player:afkModule end", self.uid)
end

-- logout模块
function player:logoutModule()
	gLog.i("==player:logoutModule begin", self.uid)

	gLog.i("==player:logoutModule end", self.uid)
end

-- 链路超时通知
function player:onLinkTimeout()
	gLog.i("player:onLinkTimeout", self:getUid(), self:getSubid())
	-- 调用gate玩家暂离
	skynet.fork(function()
		-- 设置本服地址
		local address = svrAddrMgr.getSvr(svrAddrMgr.gateSvr, dbconf.globalnodeid)
		skynet.send(address, "lua", "afk", self:getUid(), self:getSubid(), 4) --4=链路超时
	end)
end

-- 设置fd
function player:setFd(fd)
	gLog.i("player:setFd", self.uid, self.subid, "fd=", fd)
	-- 先移除fd关联
	if self.fd then
		agentCenter.playerMgr:setFdMap(self.fd, nil)
	end
    self.fd = fd
	-- 增加玩家fd关联、推送消息
	if self.fd and self.fd > 0 then
		agentCenter.playerMgr:setFdMap(self.fd, self)
		if next(self.msgNotify) then
			skynet.fork(function()
				gLog.i("player:setFd send=", self.uid, #self.msgNotify)
				while(true) do
					local c = table.remove(self.msgNotify, 1)
					if c then
						-- 数据包 = 头部2字节size+4字节sn+json数据
						local package = string.pack(">I4", 0) .. json.encode({cmd = c.cmd, data = c.msg,})
						socketdriver.send(self.fd, netpack.pack(package))
					else
						break
					end
				end
			end)
		end
	end
end

-- 处理客户端消息
function player:dispatchMsg(sn, req)
	if (sn and sn <= self.sn) or not req or not req.cmd then
		gLog.w("player:dispatchMsg ignore", self.fd, self.uid, sn <= self.sn, req and req.cmd)
		return
	end
	if dbconf.DEBUG then
		if req.cmd ~= "reqHeartbeat" then
			gLog.d("player:dispatchMsg request cmd=", req.cmd, "data=", table2string(req.data))
		end
	end
	-- 防止截获复用
	self.sn = sn
	if self.sn >= 2147483647 then -- 超过int32最大值, 重新开始
		self.sn = 0
	end
	-- notice: may yield here, socket may close.
	local _, ret = xpcall(function()
		local f = assert(clientCmd[req.cmd], "agentCenter:dispatchMsg error, cmd= "..req.cmd.." is not found")
		if type(f) == "function" then
			return f(req.data or svrFunc.emptyTb)
		end
	end, svrFunc.exception)
	if dbconf.DEBUG then
		if req.cmd ~= "reqHeartbeat" then
			gLog.d("agentCenter:dispatchMsg response cmd=", req.cmd, "ret=", table2string(ret))
		end
	end
	-- the return subid may change by multi request, check connect
	if self.fd and self.fd > 0 then
		-- 数据包 = 头部2字节size+4字节sn+json数据
		local package = string.pack(">I4", sn) .. json.encode(ret or {code = gErrDef.Err_SERVICE_EXCEPTION,})
		socketdriver.send(self.fd, netpack.pack(package))
	else
		gLog.w("agentCenter:dispatchMsg ignore", self.fd, self.uid, "cmd=", req.cmd, "ret=", ret.code)
	end
end

-- 处理客户端消息
function player:dispatchGameMsg(msg)
	if not msg or not msg.cmd then
		gLog.w("player:dispatchGameMsg ignore", self.uid, msg and msg.cmd)
		return
	end
	if dbconf.DEBUG then
		gLog.d("player:dispatchGameMsg request cmd=", msg.cmd, "data=", table2string(msg.req))
	end
	-- notice: may yield here, socket may close.
	local _, ret = xpcall(function()
		local f = assert(clientCmd[msg.cmd], "agentCenter:dispatchMsg error, cmd= ".. msg.cmd.." is not found")
		if type(f) == "function" then
			return f(self, msg.req or svrFunc.emptyTb)
		end
	end, svrFunc.exception)
	if dbconf.DEBUG then
		gLog.d("agentCenter:dispatchMsg response cmd=", msg.cmd, "ret=", table2string(ret))
	end
	-- just return ret
	return ret
end

-- 给客户端推送消息(非登录消息用agentCenter:notifyMsg())
function player:notifyMsg(cmd, msg)
	if dbconf.DEBUG then
		gLog.d("player:notifyMsg uid=", self.uid, "cmd=", cmd, "msg=", table2string(msg))
	end
	if self.online == nil then
		gLog.w("player:notifyMsg ignore", self.uid, self.fd, cmd, msg)
		return
	end
	if self.online then
		if self.fd and self.fd > 0 then
			-- 数据包 = 头部2字节size+4字节sn+json数据
			local package = string.pack(">I4", 0) .. json.encode({cmd = cmd, data = msg,})
			socketdriver.send(self.fd, netpack.pack(package))
		else
			table.insert(self.msgNotify, {cmd = cmd, msg = msg,})
		end
	else
		if not self.fd and svrFunc.systemTime() < (self.afkTime or 0) then -- 暂离30秒内缓存推送消息,客户端断线重连无需重新初始化
			table.insert(self.msgNotify, {cmd = cmd, msg = msg,})
			if #self.msgNotify > 5000 then -- 消息数量过多,报个错,客户端断线重连必须重新初始化
				self.afkTime = nil
				self.msgNotify = {}
			end
		end
	end
end

return player