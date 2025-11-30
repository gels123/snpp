--[[
	日志服务
]]
require "skynet.manager"
local skynet = require "skynet"
local svrAddrMgr = require "svrAddrMgr"
local loggerCenter = require("loggerCenter").shareInstance()

skynet.register_protocol({
	name = "text",
	id = skynet.PTYPE_TEXT,
	unpack = skynet.tostring,
	dispatch = function(session, address, msg)
		loggerCenter:skyneterr(session, address, msg)
	end
})

skynet.register_protocol({
	name = "SYSTEM",
	id = skynet.PTYPE_SYSTEM,
	unpack = function(...) return ... end,
	dispatch = function()
		loggerCenter:sigup()
	end
})

skynet.start(function()
	skynet.dispatch(skynet.PTYPE_LUA, function(session, source, cmd, level, tag, file, line, ...)
		loggerCenter:dispatch(session, source, cmd, level, tag, file, line, ...)
	end)

	svrAddrMgr.setSvr(skynet.self(), svrAddrMgr.newLoggerSvr)

	skynet.register(".logger")
end)