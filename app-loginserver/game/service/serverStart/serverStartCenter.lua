--[[
	服务器启动服务中心
]]
local skynet = require "skynet"
local serviceCenterBase = require("serviceCenterBase")
local serverStartCenter = class("serverStartCenter", serviceCenterBase)

-- 构造
function serverStartCenter:ctor()
	serverStartCenter.super.ctor(self)
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

-- 停止
function serverStartCenter:stop()
	gLog.i("serverStartCenter:stop")
	return self.serverStartMgr:stop()
end

-- 收到信号停止所有服务
function serverStartCenter:stopSignal()
	gLog.i("serverStartCenter:stopSignal")
	self:stop()
end

-- 加载服务器配置
function serverStartCenter:reloadConf(nodeid)
	gLog.i("serverStartCenter:reloadConf", nodeid)
	require("initDBConf"):set(true)
	skynet.send(svrAddrMgr.getSvr(svrAddrMgr.loginMasterSvr), "lua", "reloadConf", nodeid)
end

return serverStartCenter
