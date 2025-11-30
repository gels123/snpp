--[[
	(可选)微服务网关服务(json协议)
	Tips: 有些功能如聊天等, 可使用本微服务网关, 客户端tcp直连本服务, 也可不连由game服转发到chat服务。
]]
require "quickframework.init"
require "svrFunc"
require "configInclude"
require "sharedataLib"
require "cluster"
require "errDef"
local skynet = require "skynet"
local netpack = require "skynet.netpack"
local profile = require "skynet.profile"
local gateCenter = require("gateCenter"):shareInstance()

local ti = {}

local MSG = {
    data = assert(gateCenter.dispatchMsg),
    more = assert(gateCenter.dispatchQueue),
    open = assert(gateCenter.open),
    close = assert(gateCenter.close),
    error = assert(gateCenter.close),
}

-- 注册协议
skynet.register_protocol({
    name = "client",
    id = skynet.PTYPE_CLIENT, -- PTYPE_CLIENT = 3
})

-- 注册协议
skynet.register_protocol({
    name = "socket",
    id = skynet.PTYPE_SOCKET, -- PTYPE_SOCKET = 6
    unpack = function (msg, sz)
        return netpack.filter(gateCenter.queue, msg, sz)
    end,
    dispatch = function (session, source, q, type, ...)
        gateCenter.queue = q
        if type and MSG[type] then
            MSG[type](gateCenter, ...)
        end
    end
})

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        profile.start()

        gateCenter:dispatchCmd(session, source, cmd, ...)

        local time = profile.stop()
        if time > gOptTimeOut then
            gLog.w("gateCenter:dispatchCmd timeout time=", time, " cmd=", cmd, ...)
            if not ti[cmd] then
                ti[cmd] = {n = 0, ti = 0}
            end
            ti[cmd].n = ti[cmd].n + 1
            ti[cmd].ti = ti[cmd].ti + time
        end
    end)
    -- 注册 info 函数，便于 debug 指令 INFO 查询。
    skynet.info_func(function()
        gLog.i("info ti=", table2string(ti))
        return ti
    end)
    -- 初始化
    skynet.call(skynet.self(), "lua", "init")
    -- 设置本服地址
    svrAddrMgr.setSvr(skynet.self(), svrAddrMgr.gateSvr, dbconf.globalnodeid)
end)