--[[
    微服务agent接口（注: global服为分布式服, 每个global节点有一组公共杂项服务, 业务根据id映射节点和svrIdx）
]]
require("moduleDef")
local skynet = require ("skynet")
local dbconf = require ("dbconf")
local svrAddrMgr = require ("svrAddrMgr")
local svrConf = require ("svrConf")
local serverStartLib = require ("serverStartLib")
local agentLib = class("agentLib")

agentLib.serviceNum = 13

-- 根据id返回服务id
function agentLib:idx(id)
    return tonumber(id)%agentLib.serviceNum + 1
end

-- 获取地址(先一致性哈希确定globalnodeid,再取模)
function agentLib:getAddress(id)
    local nodeid = serverStartLib:hashNodeidGb(id)
    if dbconf.globalnodeid and dbconf.globalnodeid == nodeid then -- global服(仅有global服配置dbconf.globalnodeid)
        return svrAddrMgr.getSvr(svrAddrMgr.agentSvrGlobal, dbconf.globalnodeid, self:idx(id))
    else -- 非global服
        return svrConf:getSvrProxy(nodeid, svrAddrMgr.getSvrName(svrAddrMgr.agentSvrGlobal, nodeid, self:idx(id)))
    end
end

-- call调用
function agentLib:call(id, ...)
    return skynet.call(self:getAddress(id), "lua", ...)
end

-- send调用
function agentLib:send(id, ...)
    skynet.send(self:getAddress(id), "lua", ...)
end

-- 给客户端推送消息
function agentLib:notifyMsg(uid, cmd, msg)
    self:send(uid, "notifyMsg", msg, cmd, msg)
end

-- 给多个客户端推送消息(转发到uid对应的global-agent服处理)
function agentLib:notifyMsgBatch(uids, cmd, msg, except)
    local uid, address, tb = nil, nil, {}
    for _,v in pairs(uids) do
        uid = (type(v) == "table" and v.uid or v)
        if uid and uid ~= except then
            address = self:getAddress(uid)
            if not tb[address] then
                tb[address] = {}
            end
            table.insert(tb[address], uid)
        end
    end
    for address,v in pairs(tb) do
        skynet.send(address, "lua", "notifyMsgBatch", v, cmd, msg)
    end
end

-- call调用指定模块的指定方法(若离线则拉起)
function agentLib:callModule(uid, module, cmd, ...)
    return self:call(uid, "callModule", uid, module, cmd, ...)
end

-- send调用指定模块的指定方法(若离线则拉起)
function agentLib:sendModule(uid, module, cmd, ...)
    self:send(uid, "callModule", uid, module, cmd, ...)
end

-- call调用指定模块的指定方法(在线玩家)
function agentLib:callModuleOnline(uid, module, cmd, ...)
    return self:call(uid, "callModuleOnline", uid, module, cmd, ...)
end

-- send调用指定模块的指定方法(在线玩家)
function agentLib:sendModuleOnline(kid, uid, module, cmd, ...)
    self:send(uid, "callModuleOnline", uid, module, cmd, ...)
end

return agentLib
