--[[
    聊天模块
]]
local skynet = require("skynet")
local svrFunc = require("svrFunc")
local agentLib = require("agentLib")
local snowflake = require("snowflake")
local chatLib = require("chatLib")
local agentCenter = require("agentCenter"):shareInstance()
local baseCtrl = require("baseCtrl")
local chatCtrl = class("chatCtrl", baseCtrl)

-- 构造
function chatCtrl:ctor(uid)
    self.super.ctor(self, uid)
    self.module = "chatinfo" -- 数据表名
end

-- 初始化
function chatCtrl:init()
    if self.bInit then
        return
    end
    -- 设置已初始化
    self.bInit = true
    self.data = self:queryDB()
    if "table" ~= type(self.data) then
        self.data = self:defaultData()
        self:updateDB()
    end
    -- 清理过期好友申请列表
    local bSave = self:clearApply()
    if bSave then
        self:updateDB()
    end
    --gLog.dump(self.data, "chatCtrl:init self.data=")
end

-- 默认数据
function chatCtrl:defaultData()
    return {
        v = 1,               -- 版本号
        friends = {},        -- 好友列表
        apply = {},          -- 好友申请列表
        blacks = {},         -- 黑名单
        rooms = {},          -- 聊天房间信息
    }
end

-- 获取初始化数据
function chatCtrl:getInitData()
    return self.data or {}
end

-- 申请添加好友
function chatCtrl:addApply(uid)
    if uid == self.uid then
        gLog.d("chatCtrl:addApply err1", self.uid, uid)
        return false, gErrDef.Err_CHAT_SELF_APPLY
    end
    if self.data.friends[uid] then
        gLog.d("chatCtrl:addApply err2", self.uid, uid)
        return false, gErrDef.Err_CHAT_HAD_FRIEND
    end
    local callok, ok, code = xpcall(function()
        return agentLib:callModule(uid, gModuleDef.chatModule, "dealApply", self.uid)
    end, svrFunc.exception)
    if not callok then
        gLog.d("chatCtrl:addApply err3", self.uid, uid)
        return false, gErrDef.Err_SERVICE_EXCEPTION
    end
    if ok ~= true then
        gLog.d("chatCtrl:addApply err4", self.uid, uid)
        return false, code or gErrDef.Err_SERVICE_EXCEPTION
    end
    return true
end

-- 处理申请添加好友
function chatCtrl:dealApply(uid)
    if uid == self.uid then
        gLog.d("chatCtrl:dealApply err1", self.uid, uid)
        return false, gErrDef.Err_ILLEGAL_PARAMS
    end
    if self:hasBlacks(uid) then
        gLog.d("chatCtrl:dealApply err2", self.uid, uid)
        return false, gErrDef.Err_CHAT_IN_BLACKS
    end
    -- 清理过期好友申请列表
    self:clearApply()
    -- 是否已申请
    if self.data.apply[uid] then
        gLog.d("chatCtrl:dealApply err3", self.uid, uid)
        return false, gErrDef.Err_CHAT_HAD_APPLY
    end
    if self.data.apply[uid] then
        self.data.apply[uid].time = svrFunc.systemTime() + 604800 -- 申请时间
    else
        if table.nums(self.data.apply) >= 200 then
            gLog.d("chatCtrl:dealApply err4", self.uid, uid)
            return false, gErrDef.Err_COUNT_LIMIT
        end
        self.data.apply[uid] = {
            uid = uid,
            time = svrFunc.systemTime() + 604800, -- 申请时间
        }
    end
    self:updateDB()
    -- 推送客户端
    agentCenter:notifyMsg(self.uid, "notifyApply", {add = self.data.apply[uid],})

    return true
end

-- 回应添加好友
function chatCtrl:rspApply(uid, flag)
    if uid == self.uid then
        gLog.d("chatCtrl:rspApply err1", self.uid, uid, flag)
        return false, gErrDef.Err_CHAT_SELF_APPLY
    end
    if self.data.friends[uid] then
        gLog.d("chatCtrl:addApply err2", self.uid, uid, flag)
        if self.data.apply[uid] then
            self.data.apply[uid] = nil
            self:updateDB()
        end
        return false, gErrDef.Err_CHAT_HAD_FRIEND
    end
    -- 清理过期好友申请列表
    self:clearApply()
    --
    if flag then -- 同意
        if not self.data.apply[uid] or self.data.apply[uid].time < svrFunc.systemTime() then
            gLog.d("chatCtrl:addApply err3", self.uid, uid, flag)
            if self.data.apply[uid] then
                self.data.apply[uid] = nil
                self:updateDB()
            end
            return false, gErrDef.Err_CHAT_NO_APPLY
        end
        -- 对方添加好友
        local callok, ok, code = xpcall(function()
            return agentLib:callModule(uid, gModuleDef.chatModule, "addFriends", self.uid)
        end, svrFunc.exception)
        if not callok or ok ~= true then
            gLog.d("chatCtrl:addApply err4", self.uid, uid, flag, callok, ok)
            return false, code or gErrDef.Err_SERVICE_EXCEPTION
        end
        -- 自己添加好友
        self:addFriends(uid)
    else -- 拒绝
        if self.data.apply[uid] then
            self.data.apply[uid] = nil
            self:updateDB()
        end
    end
    return true
end

-- 清理过期好友申请列表
function chatCtrl:clearApply()
    local time, bSave = svrFunc.systemTime(), false
    for uid,v in pairs(self.data.apply) do
        if v.time < time then
            self.data.apply[uid] = nil
            bSave = true
        end
    end
    return bSave
end

-- 添加好友
function chatCtrl:addFriends(uid)
    gLog.i("chatCtrl:addFriends", self.uid, uid)
    if not self.data.friends[uid] and table.nums(self.data.friends) >= 500 then
        gLog.d("chatCtrl:addFriends err1", self.uid, uid)
        return false, gErrDef.Err_CHAT_FRIEND_LIMIT
    end
    -- 删除申请列表、黑名单
    self.data.apply[uid] = nil
    self.data.blacks[uid] = nil
    -- 添加好友
    self.data.friends[uid] = {
        uid = uid,
        top = false,                    -- 是否置顶
        time = svrFunc.systemTime(),    -- 更新时间(客户端排序用)
    }
    self:updateDB()
    -- 推送客户端
    agentCenter:notifyMsg(self.uid, "notifyFriend", {add = self.data.friends[uid],})
    return true
end

-- 删除好友
function chatCtrl:delFriends(uid)
    gLog.i("chatCtrl:delFriends", self.uid, uid)
    if self.data.friends[uid] then
        self.data.friends[uid] = nil
        self:updateDB()
        -- 推送客户端
        agentCenter:notifyMsg(self.uid, "notifyFriend", {del = {uid = uid,},})
    end
    return true
end

-- 添加/删除黑名单
function chatCtrl:setBlacks(uid, flag)
    if uid == self.uid then
        gLog.d("chatCtrl:setBlacks err1", self.uid, uid, flag)
        return false, gErrDef.Err_CANT_BE_SELF
    end
    if flag then -- 添加黑名单
        if self.data.blacks[uid] then
            gLog.d("chatCtrl:setBlacks err2", self.uid, uid, flag)
            return false, gErrDef.Err_CHAT_HAD_BLACKS
        end
        -- 对方删除好友
        local callok, ok = xpcall(function()
            return agentLib:callModule(uid, gModuleDef.chatModule, "delFriends", self.uid)
        end, svrFunc.exception)
        if not callok or ok ~= true then
            gLog.d("chatCtrl:setBlacks err3", self.uid, uid, flag)
            return false, gErrDef.Err_SERVICE_EXCEPTION
        end
        -- 自己删除好友并添加黑名单
        self.data.apply[uid] = nil
        self.data.friends[uid] = nil
        self.data.blacks[uid] = {
            uid = uid,
            time = svrFunc.systemTime(), -- 更新时间(客户端排序用)
        }
        self:updateDB()
        -- 推送客户端
        agentCenter:notifyMsg(self.uid, "notifyFriend", {del = {uid = uid,},})
    else -- 删除黑名单
        if not self.data.blacks[uid] then
            gLog.d("chatCtrl:setBlacks err4", self.uid, uid, flag)
            return false, gErrDef.Err_CHAT_NO_BLACKS
        end
        self.data.blacks[uid] = nil
        self:updateDB()
    end
    return true
end

-- 是否在黑名单
function chatCtrl:hasBlacks(uid)
    return self.data.blacks[uid] and true or false
end

-- 添加好友
function chatCtrl:addFriends(uid)
    gLog.i("chatCtrl:addFriends", self.uid, uid)
    if not self.data.friends[uid] and table.nums(self.data.friends) >= 500 then
        gLog.d("chatCtrl:addFriends err1", self.uid, uid)
        return false, gErrDef.Err_CHAT_FRIEND_LIMIT
    end
    -- 删除申请列表、黑名单
    self.data.apply[uid] = nil
    self.data.blacks[uid] = nil
    -- 添加好友
    self.data.friends[uid] = {
        uid = uid,
        top = false,                    -- 是否置顶
        time = svrFunc.systemTime(),    -- 更新时间
    }
    self:updateDB()
    -- 推送客户端
    agentCenter:notifyMsg(self.uid, "notifyFriend", {add = self.data.friends[uid],})
    return true
end

-- 获取聊天室id
function chatCtrl:getRoomId(uid, roomId)
    gLog.d("chatCtrl:getRoomId", self.uid, uid, roomId)
    if uid then -- 私聊
        if self.data.friends[uid] then
            if not self.data.friends[uid].roomId then
                roomId = tostring(snowflake.nextid())
                self.data.friends[uid].roomId = roomId
                -- 创建聊天室
                local callok, ok = xpcall(function()
                    return chatLib:call(roomId, "createRoom", roomId, gChatRoomType.group, {{uid=self.uid},{uid=uid},})
                end, svrFunc.exception)
                if not callok or ok ~= true then
                    if self.data.friends[uid].roomId == roomId then
                        self.data.friends[uid].roomId = nil
                    end
                    xpcall(function()
                        chatLib:send(roomId, "deleteRoom", roomId)
                    end, svrFunc.exception)
                    return
                end
                -- 对方设置聊天室id
                local callok, ok = xpcall(function()
                    return agentLib:callModule(uid, gModuleDef.chatModule, "setRoomId", self.uid, roomId)
                end, svrFunc.exception)
                if not callok or ok ~= true then
                    if self.data.friends[uid].roomId == roomId then
                        self.data.friends[uid].roomId = nil
                    end
                    xpcall(function()
                        chatLib:send(roomId, "deleteRoom", roomId)
                    end, svrFunc.exception)
                    return
                end
                self:updateDB()
                gLog.i("chatCtrl:getRoomId friends", self.uid, uid, roomId)
            end
            return self.data.friends[uid].roomId
        end
    elseif roomId then -- 组聊
        if self.data.rooms[roomId] then
            return roomId
        end
    end
end

-- 设置聊天室id
function chatCtrl:setRoomId(uid, roomId)
    if roomId then
        if uid then
            if self.data.friends[uid] and self.data.friends[uid].roomId == nil then
                self.data.friends[uid].roomId = roomId
                self:updateDB()
                gLog.i("chatCtrl:setRoomId friends", self.uid, uid, roomId)
                return true
            end
        else
            return self:joinRoom(roomId)
        end
    end
end

-- 加入聊天室
function chatCtrl:joinRoom(roomId)
    if not self.data.rooms[roomId] then
        gLog.i("chatCtrl:joinRoom", self.uid, roomId)
        self.data.rooms[roomId] = {
            roomId = roomId,
            time = svrFunc.systemTime(),
        }
        self:updateDB()
        -- 推送客户端
        agentCenter:notifyMsg(self.uid, "joinRoom", {roomId = roomId,})
        return true
    end
end

-- 离开聊天室
function chatCtrl:quitRoom(roomId)
    if self.data.rooms[roomId] then
        gLog.i("chatCtrl:quitRoom", self.uid, roomId)
        self.data.rooms[roomId] = nil
        self:updateDB()
        -- 推送客户端
        agentCenter:notifyMsg(self.uid, "quitRoom", {roomId = roomId,})
    end
end

return chatCtrl
