--[[
	微服务agent中心
]]
local skynet = require "skynet"
local dbconf = require "dbconf"
local svrFunc = require "svrFunc"
local playerDataLib = require "playerDataLib"
local agentLibGm = require "agentLibGm"
local serviceCenterBase = require("serviceCenterBase2")
local agentCenter = class("agentCenter", serviceCenterBase)

-- 初始化
function agentCenter:init(kid, idx)
	gLog.i("==agentCenter:init begin==", kid, idx)
	agentCenter.super.init(self, kid)

	-- 索引
	self.idx = idx
	-- 常用数据缓存
	self.addr = skynet.self()
	-- 模式(true=>客户端直连game服;false=>客户端直连global服;)
	self.mode = true

	-- 玩家管理器
	self.playerMgr = require("playerMgr").new()
	-- 计时器管理器
	self.timerMgr = require("timerMgr").new(handler(self, self.timerCallback), self.myTimer)

    gLog.i("==agentCenter:init end==", kid, idx)
end

-- 处理客户端消息
function agentCenter:dispatchMsg(fd, sn, msg)
	local player = self.playerMgr:getFdMap(fd)
	if player then
		player:dispatchMsg(sn, msg)
	else
		gLog.w("agentCenter:dispatchMsg ignore", fd)
	end
end

-- 登录
function agentCenter:login(uid, subid)
	gLog.i("agentCenter:login enter=", uid, subid)
	local player = self.playerMgr:getPlayer(uid)
	player:login(uid, subid)
	gLog.i("agentCenter:login end=", uid)
	return self.addr
end

-- 暂离
function agentCenter:afk(uid, subid, flag)
	gLog.i("agentCenter:afk enter=", uid, subid, flag)
	local player = self.playerMgr:getPlayer(uid, true)
	if player then
		player:afk(flag)
	else
		gLog.w("agentCenter:afk ignore=", uid, subid, flag)
	end
	gLog.i("agentCenter:afk end=", uid, subid, flag)
end

-- 登出
function agentCenter:logout(uid, subid, flag)
	gLog.i("agentCenter:logout enter=", uid, subid, flag)
	local player = self.playerMgr:getPlayer(uid, true)
	if player then
		player:logout(flag)
		self.playerMgr:delPlayer(uid)
	else
		gLog.w("agentCenter:afk ignore=", uid, subid, flag)
	end
	gLog.i("agentCenter:logout end=", uid, subid, flag)
end

-- 设置fd
function agentCenter:setFd(fd, uid, subid)
	if fd and uid and subid then
		gLog.i("agentCenter:setFd enter=", fd, uid, subid)
		local player = self.playerMgr:getPlayer(uid, true)
		if player then
			-- 设置fd
			player:setFd(fd)
			-- checkin
			local ok, isInit = player:checkin(subid)
			gLog.i("agentCenter:setFd end=", fd, uid, subid)
			return ok, isInit
		else
			gLog.w("agentCenter:setFd ignore=", fd, uid, subid)
		end
	end
end

-- 获取已存在的player
function agentCenter:getPlayer(uid)
	return self.playerMgr:getPlayer(uid, true)
end

-- 给客户端推送消息
function agentCenter:notifyMsg(uid, cmd, msg)
	assert(uid and cmd and msg)
	if self.mode then -- 客户端直连game服模式, 消息转发到玩家所在game服
		xpcall(function()
			local kid = playerDataLib:getKidOfUid(self.kid, uid) -- 玩家所在kid
			if type(kid) == "number" and kid > 0 then
				agentLibGm:notifyMsg(kid, uid, cmd, msg)
			end
		end, svrFunc.exception)
	else
		local player = self.playerMgr:getPlayer(uid, true)
		if player then
			player:notifyMsg(cmd, msg)
		else
			gLog.d("agentCenter:notifyMsg ignore=", uid, cmd, msg)
		end
	end
end

-- 给客户端推送消息
function agentCenter:notifyMsgBatch(uids, cmd, msg)
	assert(uids and #uids > 0 and cmd and msg)
	if self.mode then -- 客户端直连game服模式, 消息转发到玩家所在game服
		xpcall(function()
			local kid = playerDataLib:getKidOfUid(self.kid, uids[1]) -- 玩家所在kid
			if type(kid) == "number" and kid > 0 then
				agentLibGm:notifyMsgBatch(kid, uids, cmd, msg)
			end
		end, svrFunc.exception)
	else
		for _,uid in pairs(uids) do
			local player = self.playerMgr:getPlayer(uid, true)
			if player then
				player:notifyMsg(cmd, msg)
			else
				gLog.d("agentCenter:notifyMsg ignore=", uid, cmd, msg)
			end
		end
	end
end

-- call调用指定模块的指定方法(若离线则拉起)
function agentCenter:callModule(uid, module, cmd, ...)
	assert(uid and module and cmd)
	local player = self.playerMgr:getPlayer(uid, true)
	if not player then
		player = self.playerMgr:getPlayer(uid)
		player:login(uid, nil)
	end
	local ctrl = player:getModule(module)
	local f = ctrl[cmd]
	if type(f) == "function" then
		return f(ctrl, ...)
	else
		gLog.e("agentCenter:callModule err", uid, module, cmd, ...)
	end
end

-- call调用指定模块的指定方法(在线玩家)
function agentCenter:callModuleOnline(uid, module, cmd, ...)
	assert(uid and module and cmd)
	local player = self.playerMgr:getPlayer(uid, true)
	if player then
		local ctrl = player:getModule(module)
		local f = ctrl[cmd]
		if type(f) == "function" then
			return f(ctrl, ...)
		else
			gLog.e("agentCenter:callModuleOnline err", uid, module, cmd, ...)
		end
	else
		gLog.d("agentCenter:callModuleOnline ignore", uid, module, cmd, ...)
	end
end

-- 处理game服转发的请求
function agentCenter:dispatchGameMsg(uid, msg)
	if self.mode and uid and msg then
		local player = self.playerMgr:getPlayer(uid, true)
		if not player then
			player = self.playerMgr:getPlayer(uid)
			player:login(uid, nil)
		end
		return player:dispatchGameMsg(msg)
	else
		return {code = gErrDef.Err_NOT_SUPPORT_GAME_REQ,}
	end
end

-- 计时器回调
function agentCenter:timerCallback(data)
	if dbconf.DEBUG then
		gLog.d("agentCenter:timerCallback data=", table2string(data))
	end
	local uid, timerType = data.id, data.timerType
	if self.timerMgr:hasTimer(uid, timerType) then
		local player = self:getPlayer(uid)
		if player then
			if timerType == gAgentTimerType.heartbeat then
				player:onLinkTimeout()
			elseif timerType == gAgentTimerType.free then
				self.playerMgr:delPlayer(uid)
			else
				gLog.w("agentCenter:timerCallback ignore", uid, timerType)
			end
		else
			gLog.w("agentCenter:timerCallback ignore", uid, timerType)
		end
	end
	--gLog.dump(self, "agentCenter:timerCallback self=")
end

return agentCenter
