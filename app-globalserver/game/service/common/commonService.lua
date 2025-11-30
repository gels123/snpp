--[[
	公共杂项服务（注: global服为分布式服, 每个global节点有一组公共杂项服务, 业务根据id映射节点和svrIdx）
]]
require "quickframework.init"
require "svrFunc"
require "errDef"
require "configInclude"
require "sharedataLib"
require "cluster"
local skynet = require "skynet"
local svrAddrMgr = require "svrAddrMgr"
local svrFunc = require "svrFunc"
local commonCenter = require("commonCenter"):shareInstance()

local kid, idx = ...
kid, idx = tonumber(kid), tonumber(idx)
assert(kid and idx)

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        --gLog.d("commonCenter.dispatchCmd enter=", source, cmd, ...)
        xpcall(commonCenter.dispatchCmd, svrFunc.exception, commonCenter, session, source, cmd, ...)
    end)
    -- 设置本服地址
    svrAddrMgr.setSvr(skynet.self(), svrAddrMgr.commonSvr, kid, idx)
    -- 初始化
    skynet.call(skynet.self(), "lua", "init", kid, idx)
    -- 通知启动服务，本服务已初始化完成
    require("serverStartLib"):finishInit(svrAddrMgr.getSvrName(svrAddrMgr.commonSvr, kid, idx), skynet.self())
end)