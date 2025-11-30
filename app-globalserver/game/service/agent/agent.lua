--[[
    微服务agent（注: global服为分布式服, 可横向拓展, 业务根据id映射节点和idx）
]]
require "quickframework.init"
require "svrFunc"
require "errDef"
require "configInclude"
require "sharedataLib"
require "cluster"
require "agentDef"
require "moduleDef"
require "itemDef"
local skynet = require "skynet"
local netpack = require "skynet.netpack"
local svrAddrMgr = require "svrAddrMgr"
local json = require "json"
local svrFunc = require "svrFunc"
local agentCenter = require("agentCenter"):shareInstance()

local kid, idx = ...
kid, idx = tonumber(kid), tonumber(idx)
assert(kid and idx)

-- 注册客户端协议
skynet.register_protocol({
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = function(msg, sz)
        --gLog.d("agent unpack json=", skynet.unpack(msg, sz))
        msg = skynet.unpack(msg, sz)
        local sn = string.unpack(">I4", msg, 1, 4)
        local req = json.decode(msg:sub(5, -1))
        return sn, req
    end,
    dispatch = function(_, fd, sn, req)
        --gLog.d("agent dispatch=", _, fd, sn, req)
        if fd and sn and req then
            agentCenter:dispatchMsg(fd, sn, req)
        end
    end,
})

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        --gLog.d("agentCenter.dispatchCmd enter=", source, cmd, ...)
        xpcall(agentCenter.dispatchCmd, svrFunc.exception, agentCenter, session, source, cmd, ...)
    end)
    -- 设置本服地址
    svrAddrMgr.setSvr(skynet.self(), svrAddrMgr.agentSvrGlobal, kid, idx)
    -- 初始化
    skynet.call(skynet.self(), "lua", "init", kid, idx)
    -- 通知启动服务，本服务已初始化完成
    require("serverStartLib"):finishInit(svrAddrMgr.getSvrName(svrAddrMgr.agentSvrGlobal, kid, idx), skynet.self())
end)
