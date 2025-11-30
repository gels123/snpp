--[[
	服务器启动服务(其它服务都应向本服务同步状态)
]]
require "quickframework.init"
require "svrFunc"
require "configInclude"
require "sharedataLib"
require("cluster")
local skynet = require "skynet"
local lextra = require "lextra"
local serviceCenter = require("serverStartCenter"):shareInstance()

-- 接收来自于c/c++层消息
skynet.register_protocol {
    name = "txt",
    id = 0,
    unpack = lextra.cstr_unpack,
}

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        xpcall(serviceCenter.dispatchCmd, svrFunc.exception, serviceCenter, session, source, cmd, ...)
    end)

    skynet.dispatch("txt", function(session, source, cmd, ...)
        gLog.i("serverStartCenter txt enter => ", session, source, cmd, ...)
        xpcall(serviceCenter.dispatchCmd, svrFunc.exception, serviceCenter, session, source, cmd, ...)
    end)

    -- 设置本服地址
    svrAddrMgr.setSvr(skynet.self(), svrAddrMgr.startSvr)
    
    -- 初始化
    skynet.call(skynet.self(), "lua", "init")
end)