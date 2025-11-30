--[[
    玩家管理器
]]
local skynet = require("skynet")
local svrFunc = require("svrFunc")
local playerC = require("player")
local agentCenter = require("agentCenter"):shareInstance()
local playerMgr = class("playerMgr")

-- 构造
function playerMgr:ctor()
    -- 玩家列表(值弱表)
    self.players = {}
    -- 玩家fd关联(值弱表)
    self.fdMap = {}
    setmetatable(self.fdMap, {__mode = "v"})
end

-- 获取player
function playerMgr:getPlayer(uid, noNew)
    assert(uid)
    local sq = agentCenter:getSq(uid)
    local player = nil
    sq(function()
        if not self.players[uid] then
            if not noNew then --noNew==true, 不新建
                self.players[uid] = playerC.new(uid)
                -- 此时需开启释放计时器, 否则可能数据无法释放
                local time = svrFunc.systemTime() + gAgentFreeTime
                agentCenter.timerMgr:updateTimer(uid, gAgentTimerType.free, time)
            end
        end
        player = self.players[uid]
    end)
    if not player then -- 防止sq泄漏
        agentCenter:delSq(uid)
    end
    return player
end

-- 释放player
function playerMgr:delPlayer(uid)
    local sq = agentCenter:getSq(uid)
    sq(function()
        local player = self.players[uid]
        if player then
            -- 删除倒计时
            for k,v in pairs(gAgentTimerType) do
                agentCenter.timerMgr:updateTimer(uid, v, 0)
            end
            -- 删除fd
            player:setFd(nil)
            -- 释放player
            self.players[uid] = nil
            player = nil
        end
    end)
    -- 释放sq
    agentCenter:delSq(uid)
    sq = nil
end

-- 根据fd获取player
function playerMgr:getFdMap(fd)
    if fd then
        return self.fdMap[fd]
    end
end

-- 维护玩家fd关联
function playerMgr:setFdMap(fd, player)
    if fd then
        if player then
            self.fdMap[fd] = player
        else
            self.fdMap[fd] = nil
        end
    end
end

return playerMgr
