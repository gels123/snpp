--[[
    日志
        需要在 gamestartconf 中自定义
        logger = "myloggers"
        logservice = "snlua"
]]
local skynet = require "skynet"
local svrAddrMgr = require "svrAddrMgr"
local dbconf = require "dbconf"
local tableinsert = table.insert
local tableconcat = table.concat
local tablepack = table.pack
local tostring = tostring
local newLog = {}

local address, file, line = nil, nil, nil -- logger服地址
newLog.bFile = dbconf.DEBUG     -- 是否打印文件信息

newLog.defaultTag = function () -- 定制log tag
    return string.format(" %s ", skynet.address(skynet.self()))
end

newLog.fileInfo = function ()
	local di = debug.getinfo(3, 'Sl')
    return string.match(di.source,"%a+.lua"), di.currentline -- 只返回文件名,行数
end

newLog.concat = function (...)
    local ret = {}
    local data = tablepack(...)
    for i = 1, data.n do
        local v = data[i]
        local tmpType = type(v)
        if tmpType ~= "number" or tmpType ~= "string" then
            tableinsert(ret, tostring(v))
        else
            tableinsert(ret, v)
        end
    end
    return tableconcat(ret," ")
end

newLog.d = function (...)
    if dbconf.DEBUG then
        if not address then
            address = svrAddrMgr.getSvr(svrAddrMgr.newLoggerSvr)
        end
        if address then
            file, line = nil, nil
            if newLog.bFile then
                file, line = newLog.fileInfo()
            end
            local tag = newLog.defaultTag()
            skynet.send(address, skynet.PTYPE_LUA, "log", 0, tag, file, line, newLog.concat(...))
        end
    end
end

newLog.i = function (...)
    if not address then
        address = svrAddrMgr.getSvr(svrAddrMgr.newLoggerSvr)
    end
    if address then
        file, line = nil, nil
        if newLog.bFile then
            file, line = newLog.fileInfo()
        end
        local tag = newLog.defaultTag()
        skynet.send(address, skynet.PTYPE_LUA, "log", 1, tag, file, line, newLog.concat(...))
    end
end

newLog.w = function (...)
    if not address then
        address = svrAddrMgr.getSvr(svrAddrMgr.newLoggerSvr)
    end
    if address then
        file, line = nil, nil
        if newLog.bFile then
            file, line = newLog.fileInfo()
        end
        local tag = newLog.defaultTag()
        skynet.send(address, skynet.PTYPE_LUA, "log", 2, tag, file, line, newLog.concat(...))
    end
end

newLog.e = function (...)
    if not address then
        address = svrAddrMgr.getSvr(svrAddrMgr.newLoggerSvr)
    end
    if address then
        file, line = nil, nil
        if newLog.bFile then
            file, line = newLog.fileInfo()
        end
        local tag = newLog.defaultTag()
        local logMsg = newLog.concat(...)
        local logMsgAppendedTb = debug.traceback(logMsg, 3)
        skynet.send(address, skynet.PTYPE_LUA, "log", 3, tag, file, line, logMsgAppendedTb)
    end
end

newLog.dump = function (tbl, desc, nesting)
    if dbconf.DEBUG then
        if not address then
            address = svrAddrMgr.getSvr(svrAddrMgr.newLoggerSvr)
        end
        if address then
            file, line = nil, nil
            if newLog.bFile then
                file, line = newLog.fileInfo()
            end
            local tag = newLog.defaultTag()
            skynet.send(address, skynet.PTYPE_LUA, "log", 1, tag, file, line, table2string(tbl, desc, nesting))
        end
    end
end

return newLog
