--[[
	聊天服务接口（注: global服为分布式服, 每个global节点有一组聊天服务, 业务根据roomId映射节点和svrIdx）
]]
require "chatDef"
local skynet = require ("skynet")
local dbconf = require ("dbconf")
local svrAddrMgr = require ("svrAddrMgr")
local svrConf = require ("svrConf")
local json = require ("json")
local serverStartLib = require ("serverStartLib")
local chatLib = class("chatLib")

chatLib.serviceNum = 13

-- 根据id返回服务id
function chatLib:idx(id)
    return tonumber(id)%chatLib.serviceNum + 1
end

-- 获取地址
function chatLib:getAddress(id)
    local nodeid = serverStartLib:hashNodeidGb(id)
    if dbconf.globalnodeid and dbconf.globalnodeid == nodeid then -- global服(仅有global服配置dbconf.globalnodeid)
        return svrAddrMgr.getSvr(svrAddrMgr.chatSvr, dbconf.globalnodeid, self:idx(id))
    else -- 非global服
        return svrConf:getSvrProxy(nodeid, svrAddrMgr.getSvrName(svrAddrMgr.chatSvr, nodeid, self:idx(id)))
    end
end

-- call调用
function chatLib:call(id, ...)
    return skynet.call(self:getAddress(id), "lua", ...)
end

-- send调用
function chatLib:send(id, ...)
    skynet.send(self:getAddress(id), "lua", ...)
end

-- 系统发送聊天消息如跑马灯等
-- @msg => 聊天消息 见sChatMsg结构 {uid=0, tp=gChatMsgType.text, txt = "hello", time=1683870000}
function chatLib:chat(id, msg)
    if type(msg.txt) == "table" then
        msg.txt = json.encode(msg.txt)
    end
    self:send(id, "chat", id, msg)
end

return chatLib
