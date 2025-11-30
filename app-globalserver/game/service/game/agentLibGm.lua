--[[
	(游戏服)玩家代理服务对外接口
--]]
require("moduleDef")
local skynet = require "skynet"
local svrAddrMgr = require "svrAddrMgr"
local agentLib = class("agentLib")

-- 获取服务地址
function agentLib:getAddress(kid)
    return svrAddrMgr.getSvr(svrAddrMgr.agentPoolSvr, kid)
end

-- call调用
function agentLib:call(kid, ...)
    return skynet.call(self:getAddress(kid), "lua", ...)
end

-- send调用
function agentLib:send(kid, ...)
    skynet.send(self:getAddress(kid), "lua", ...)
end

-- call玩家代理(若离线则拉起)
function agentLib:callAgent(kid, uid, ...)
    return self:call(kid, "callAgent", uid, ...)
end

-- send玩家代理(若离线则拉起)
function agentLib:sendPlayerAgent(kid, uid, ...)
    self:send(kid, "sendPlayerAgent", uid, ...)
end

-- call在线的玩家代理
function agentLib:callOnlineAgent(kid, uid, ...)
    return self:call(kid, "callOnlineAgent", uid, ...)
end

-- send在线的玩家代理
function agentLib:sendOnlineAgent(kid, uid, ...)
    self:send(kid, "sendOnlineAgent", uid, ...)
end

-- call所有在线的玩家代理
function agentLib:callAllOnlineAgents(kid, ...)
    return self:call(kid, "callAllOnlineAgents", ...)
end

-- send所有在线的玩家代理
function agentLib:sendAllOnlineAgents(kid, ...)
    self:send(kid, "sendAllOnlineAgents", ...)
end

-- 给客户端推送消息
function agentLib:notifyMsg(kid, uid, cmd, msg)
    self:send(kid, "notifyMsg", uid, cmd, msg)
end

-- 批量通知在线玩家
function agentLib:notifyMsgBatch(kid, uids, cmd, msg)
    self:send(kid, "notifyMsgBatch", uids, cmd, msg)
end

-- 批量通知所有在线玩家
function agentLib:notifyMsgAll(kid, cmd, msg)
    self:send(kid, "notifyMsgAll", cmd, msg)
end

-- 获取在线人数
function agentLib:getOnlinePlayersNum(kid)
    return self:call(kid, "getOnlinePlayersNum")
end

-- 获取在线玩家UID、离线玩家UID
function agentLib:getOnlinePlayers(kid, uids)
    return self:call(kid, "getOnlinePlayers", uids)
end

-- 获取联盟ID
function agentLib:getAid(kid, uid)
    return self:callAgent(kid, uid, "getAid")
end

-- call调用指定模块的指定方法(若离线则拉起) eg: agentLib:callModule(1, 15, gModuleDef.lordModule, "f")
function agentLib:callModule(kid, uid, module, cmd, ...)
    return self:call(kid, "callAgent", uid, "callModule", module, cmd, ...)
end

-- send调用指定模块的指定方法(若离线则拉起)
function agentLib:sendModule(kid, uid, module, cmd, ...)
    self:send(kid, "callAgent", uid, "sendModule", module, cmd, ...)
end

-- call调用指定模块的指定方法(在线玩家)
function agentLib:callModuleOnline(kid, uid, module, cmd, ...)
    return self:call(kid, "callOnlineAgent", uid, "callModule", module, cmd, ...)
end

-- send调用指定模块的指定方法(在线玩家)
function agentLib:sendModuleOnline(kid, uid, module, cmd, ...)
    self:send(kid, "sendOnlineAgent", uid, "sendModule", module, cmd, ...)
end

-- call调用指定模块的指定方法(所有在线玩家)
function agentLib:callModuleAllOnline(kid, module, cmd, ...)
    return self:call(kid, "callAllOnlineAgents", "callModule", module, cmd, ...)
end

-- send调用指定模块的指定方法(所有在线玩家)
function agentLib:sendModuleAllOnline(kid, module, cmd, ...)
    self:send(kid, "sendAllOnlineAgents", "sendModule", module, cmd, ...)
end

return agentLib