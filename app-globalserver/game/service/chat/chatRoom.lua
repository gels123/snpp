--[[
	聊天室
]]
local skynet = require("skynet")
local chatCenter = require("chatCenter"):shareInstance()
local svrFunc = require("svrFunc")
local playerDataLib = require("playerDataLib")
local agentLib = require("agentLib")
local chatRoom = class("chatRoom")

-- 构造
function chatRoom:ctor(id)
    self.id = assert(id)                -- 聊天室id
    self.module = "chat"	            -- 数据表名
    self.data = nil		                -- 数据
    self.bInit = false                  -- 是否已初始化
end

-- 初始化
function chatRoom:init()
    self.data = self:queryDB()
    if "table" ~= type(self.data) then
        self.data = self:defaultData()
        self:updateDB()
    end
end

-- 默认数据
function chatRoom:defaultData()
    return {
        id = self.id,                   -- 聊天室id
        tp = gChatRoomType.group,       -- 聊天室类型
        kid = nil,                      -- 聊天室王国
        aid = nil,                      -- 聊天室联盟
        members = {},                   -- 聊天室成员
        memcnt = 0,                     -- 聊天室成员数量
        msgId = 0,                      -- 聊天消息id
        msgList = {},                   -- 聊天消息列表
        time = svrFunc.systemTime(),    -- 聊天室创建时间
    }
end

-- 重置数据
function chatRoom:resetData(tp, members)
    self.data.tp = tp or 0
    self.data.members = members or {}
    self.data.msgId = 0
    self.data.msgList = {}
    self:updateDB()
end

-- 创建聊天室
function chatRoom:createRoom(tp, members, kid, aid)
    if tp == gChatRoomType.kingdom then
        assert(kid and kid > 0)
    elseif tp == gChatRoomType.alliance then
        assert(aid and aid > 0)
    end
    self.data.tp = tp or gChatRoomType.group
    self.data.kid = kid or nil
    self.data.aid = aid or nil
    self:joinRoom(members)
    self:updateDB()
    return true
end

-- 加入聊天室
function chatRoom:joinRoom(members)
    if not members or #members <= 0 then
        return false
    end
    local bSave = false
    for k,v in ipairs(members) do
        if v.uid then
            self.data.members[v.uid] = {
                uid = v.uid,                        -- 玩家id
                admin = v.admin and true or nil,    -- 是否组群管理员
                time = svrFunc.systemTime(),        -- 加入时间
            }
            bSave = true
        end
    end
    self.data.memcnt = table.nums(self.data.members)
    return bSave
end

-- 退出聊天室
function chatRoom:quitRoom(members)
    if not members or #members <= 0 then
        return false
    end
    local flag = false
    for k,v in ipairs(members) do
        if v.uid and self.members[v.uid] then
            self.data.members[v.uid] = nil
            flag = true
        end
    end
    self.data.memcnt = table.nums(self.data.members)
    -- 若成员数<=1, 则解散聊天室
    if self.data.memcnt <= 1 then
        self:dimissRoom()
    end
    return flag
end

-- 解散聊天室
function chatRoom:dimissRoom()
    self.data = nil
    -- 删除数据库
    self:deleteDB()
end

-- 发送聊天消息
-- @msg => 聊天消息 见sChatMsg结构 {uid=101, tp=gChatMsgType.text, txt = "hello", time=1683870000}
function chatRoom:chat(msg)
    if not msg or not msg.uid or not msg.tp or not gChatMsgType2[msg.tp] or not msg.txt then
        gLog.e("chatRoom:sendMsg err1", self.id, msg.uid, msg.tp, msg.txt)
        return false, gErrDef.Err_ILLEGAL_PARAMS
    end
    if self.data.tp == gChatRoomType.group then -- 私聊/组聊
        if msg.uid <= 0 or not self.data.members[msg.uid] then
            gLog.e("chatRoom:sendMsg err2", self.id, msg.uid, msg.tp, msg.txt)
            return false, gErrDef.Err_CHAT_SEND_MSG_ERR
        end
    elseif self.data.tp == gChatRoomType.alliance then -- 联盟聊天
        if msg.uid <= 0 then
            gLog.e("chatRoom:sendMsg err3", self.id, msg.uid, msg.tp, msg.txt)
            return false, gErrDef.Err_CHAT_SEND_MSG_ERR
        end
    else -- 王国聊天
        msg.uid = 0
    end
    -- 填充消息id, 超过int64最大值则重新开始
    self.data.msgId = self.data.msgId + 1
    if self.data.msgId >= 2147483647 then
        self.data.msgId = 1
    end
    msg.id = self.data.msgId
    -- 填充消息时间
    if not msg.time then
        msg.time = svrFunc.systemTime()
    end
    --
    table.insert(self.data.msgList, msg)
    if #self.data.msgList > 500 then
        table.remove(self.data.msgList, 1)
    end
    self:updateDB()
    -- 推送客户端
    if self.data.tp == gChatRoomType.group then
        --for k,v in pairs(self.data.members) do
        --    if v.uid ~= msg.uid then
        --        agentLib:send(v.uid, "notifyMsg", v.uid, "notifyChat", {id = self.id, msg = msg,})
        --    end
        --end
        agentLib:notifyMsgBatch(self.data.members, "notifyChat", {id = self.id, msg = msg,}, msg.uid)
    end
    return true
end

-- 查询数据库
function chatRoom:queryDB()
    assert(self.id and self.module, "queryDB error!")
    return playerDataLib:query(chatCenter:getKid(), self.id, self.module)
end

-- 更新数据库
function chatRoom:updateDB()
    local data = self:getDataDB()
    assert(self.id and self.module and data, "updateDB error!")
    playerDataLib:sendUpdate(chatCenter:getKid(), self.id, self.module, data)
end

-- 获取存库数据
function chatRoom:getDataDB()
    return self.data
end

-- 删除数据库
function chatRoom:deleteDB()
    playerDataLib:sendDelete(chatCenter:getKid(), self.id, self.module)
end

return chatRoom
