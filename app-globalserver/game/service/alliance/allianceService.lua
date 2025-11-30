--[[
    联盟服务
--]]
require "quickframework.init"
require "svrFunc"
require "configInclude"
require "sharedataLib"
require "moduleDef"
require "errDef"
require "agentDef"
require "allianceDef"
local skynet = require("skynet")
local cluster = require("skynet.cluster")
local profile = require("skynet.profile")
local svrAddrMgr = require("svrAddrMgr")
local allianceCenter = require("allianceCenter"):shareInstance()

local kid, idx = ...
kid, idx = tonumber(kid), tonumber(idx)
assert(kid and idx)

skynet.start(function()
	skynet.dispatch("lua", function(session, source, cmd, ...)
        profile.start()

        --gLog.d("allianceCenter:dispatchCmd", session, source, cmd, ...)
        allianceCenter:dispatchCmd(session, source, cmd, ...)

        local time = profile.stop()
        if time > 1 then
            gLog.w("allianceCenter:dispatchCmd timeout time=", time, "cmd=", cmd, ...)
        end
	end)
    -- 设置地址
    svrAddrMgr.setSvr(skynet.self(), svrAddrMgr.allianceSvr, kid, idx)
    -- 初始化
    skynet.call(skynet.self(), "lua", "init", kid, idx)
    -- 通知启动服务, 本服务已初始化完成
    require("serverStartLib"):finishInit(svrAddrMgr.getSvrName(svrAddrMgr.allianceSvr, kid, idx), skynet.self())
end)
