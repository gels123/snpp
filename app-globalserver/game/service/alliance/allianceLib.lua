--[[
	联盟接口
]]
local skynet = require("skynet")
local dbconf = require ("dbconf")
local svrAddrMgr = require ("svrAddrMgr")
local svrConf = require ("svrConf")
local initDBConf = require ("initDBConf")
local serverStartLib = require ("serverStartLib")
local allianceLib = class("allianceLib")

-- 服务数量
allianceLib.serviceNum = 17

-- 根据id返回服务id
function allianceLib:idx(aid)
    return tonumber(aid) % allianceLib.serviceNum + 1
end

-- 获取地址
function allianceLib:getAddress(aid)
    local nodeid = serverStartLib:hashNodeidGb(aid)
    if dbconf.globalnodeid and dbconf.globalnodeid == nodeid then -- global服(仅有global服配置dbconf.globalnodeid)
        return svrAddrMgr.getSvr(svrAddrMgr.allianceSvr, dbconf.globalnodeid, self:idx(aid))
    else -- 非global服
        return svrConf:getSvrProxy(nodeid, svrAddrMgr.getSvrName(svrAddrMgr.allianceSvr, nodeid, self:idx(aid)))
    end
end

-- call调用指定模块的指定方法
function allianceLib:call(aid, ...)
    return skynet.call(self:getAddress(aid), "lua", ...)
end

-- send调用指定模块的指定方法
function allianceLib:send(aid, ...)
    skynet.send(self:getAddress(aid), "lua", ...)
end

-- call调用指定模块的指定方法
function allianceLib:callModule(aid, module, cmd, ...)
    return skynet.call(self:getAddress(aid), "lua", "callModule", aid, module, cmd, ...)
end

-- send调用指定模块的指定方法
function allianceLib:sendModule(aid, module, cmd, ...)
    skynet.send(self:getAddress(aid), "lua", "sendModule", aid, module, cmd, ...)
end

-- 玩家登录
function allianceLib:login(aid, uid)
    return skynet.call(self:getAddress(aid), "lua", "login", aid, uid)
end

-- 玩家checkin
function allianceLib:checkin(aid, uid)
    skynet.send(self:getAddress(aid), "lua", "checkin", aid, uid)
end

-- 玩家afk
function allianceLib:afk(aid, uid)
    skynet.send(self:getAddress(aid), "lua", "afk", aid, uid)
end

-- 玩家彻底离线
function allianceLib:logout(aid, uid)
    skynet.send(self:getAddress(aid), "lua", "logout", aid, uid)
end

return allianceLib