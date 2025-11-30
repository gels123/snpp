--[[
    聊天服务接口（注: global服为分布式服, 每个global节点有一组聊天服务, 业务根据roomId映射节点和svrIdx）
]]
require "quickframework.init"
require "svrFunc"
require "errDef"
require "chatDef"
require "configInclude"
require "sharedataLib"
require "cluster"
local skynet = require "skynet"
local svrFunc = require "svrFunc"
local svrAddrMgr = require "svrAddrMgr"
local chatCenter = require("chatCenter"):shareInstance()

local kid, idx = ...
kid, idx = tonumber(kid), tonumber(idx)
assert(kid and idx)

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        --gLog.d("chatCenter.dispatchCmd enter=", source, cmd, ...)
        xpcall(chatCenter.dispatchCmd, svrFunc.exception, chatCenter, session, source, cmd, ...)
    end)
    -- 设置本服地址
    svrAddrMgr.setSvr(skynet.self(), svrAddrMgr.chatSvr, kid, idx)
    -- 初始化
    skynet.call(skynet.self(), "lua", "init", kid, idx)
    -- 通知启动服务, 本服务已初始化完成
    require("serverStartLib"):finishInit(svrAddrMgr.getSvrName(svrAddrMgr.chatSvr, kid, idx), skynet.self())
end)