--[[
    聊天室管理器
]]
local skynet = require("skynet")
local svrFunc = require("svrFunc")
local chatRoomC = require("chatRoom")
local playerDataLib = require("playerDataLib")
local chatCenter = require("chatCenter"):shareInstance()
local chatMgr = class("chatMgr")

-- 构造
function chatMgr:ctor()
    -- 聊天室列表
    self.rooms = {}
end

-- 获取聊天室
function chatMgr:getRoom(roomId, noNew)
    assert(roomId)
    local sq = chatCenter:getSq(roomId)
    local chatRoom = nil
    sq(function()
        chatRoom = self.rooms[roomId]
        if not chatRoom then
            if not noNew then --noNew==true, 不新建
                chatRoom = chatRoomC.new(roomId)
                chatRoom:init()
                self.rooms[roomId] = chatRoom
            end
        end
    end)
    if not chatRoom then -- 防止sq泄漏
        chatCenter:delSq(roomId)
    else -- 此时需开启释放计时器, 否则可能数据无法释放
        local time = svrFunc.systemTime()
        time = time - time%3600 + gChatRoomFreeTime
        chatCenter.timerMgr:updateTimer(roomId, gChatTimerType.free, time)
    end
    return chatRoom
end

-- 释放聊天室
function chatMgr:releaseRoom(roomId)
    local sq = chatCenter:getSq(roomId)
    sq(function()
        local chatRoom = self.rooms[roomId]
        if chatRoom then
            -- 删除倒计时
            for k,v in pairs(gChatTimerType) do
                chatCenter.timerMgr:updateTimer(roomId, v, 0)
            end
            -- 释放
            self.rooms[roomId] = nil
            chatRoom = nil
        end
    end)
    -- 释放sq
    chatCenter:delSq(roomId)
    sq = nil
end

-- 删除聊天室
function chatMgr:deleteRoom(roomId)
    self:releaseRoom(roomId)
    playerDataLib:sendDelete(chatCenter:getKid(), roomId, "chat")
end

return chatMgr
