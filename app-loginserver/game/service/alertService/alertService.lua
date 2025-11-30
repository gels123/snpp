--[[
    报错信息推送服务
]]
require("quickframework.init")
require("cluster")
require("svrFunc")
local skynet = require "skynet"
local profile = require "skynet.profile"
local alertCenter = require("alertCenter"):shareInstance()

local ti = {}

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        --gLog.d("alertCenter cmd enter => ", session, source, cmd, ...)

        profile.start()

        alertCenter:dispatchCmd(session, source, cmd, ...)

        local time = profile.stop()
        if time > 1 then
            gLog.w("alertCenter:dispatchCmd timeout time=", time, " cmd=", cmd, ...)
            if not ti[cmd] then
                ti[cmd] = {n = 0, ti = 0}
            end
            ti[cmd].n = ti[cmd].n + 1
            ti[cmd].ti = ti[cmd].ti + time
        end
    end)

    -- 初始化
    skynet.call(skynet.self(), "lua", "init")

    -- 设置本服地址
    svrAddrMgr.setSvr(skynet.self(), svrAddrMgr.alertSvr)

    -- 注册 info 函数, 便于 INFO 指令查询
    skynet.info_func(function()
        gLog.dump(ti, "alertService ti=", 10)
        return ti
    end)
end)