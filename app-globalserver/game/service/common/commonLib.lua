--[[
	公共杂项服务接口（注: global服为分布式服, 每个global节点有一组公共杂项服务, 业务根据id映射节点和svrIdx）
]]
local skynet = require ("skynet")
local dbconf = require ("dbconf")
local svrAddrMgr = require ("svrAddrMgr")
local svrConf = require ("svrConf")
local serverStartLib = require ("serverStartLib")
local commonLib = class("commonLib")

commonLib.serviceNum = 13

-- 根据id返回服务id
function commonLib:idx(id)
    return (tonumber(id) - 1)%commonLib.serviceNum + 1
end

-- 获取地址
function commonLib:getAddress(id)
    local nodeid = serverStartLib:hashNodeidGb(id)
    if dbconf.globalnodeid and dbconf.globalnodeid == nodeid then -- global服(仅有global服配置dbconf.globalnodeid)
        return svrAddrMgr.getSvr(svrAddrMgr.commonSvr, dbconf.globalnodeid, self:idx(id))
    else -- 非global服
        return svrConf:getSvrProxy(nodeid, svrAddrMgr.getSvrName(svrAddrMgr.commonSvr, nodeid, self:idx(id)))
    end
end

-- call调用
function commonLib:call(id, ...)
    return skynet.call(self:getAddress(id), "lua", ...)
end

-- send调用
function commonLib:send(id, ...)
    skynet.send(self:getAddress(id), "lua", ...)
end

return commonLib
