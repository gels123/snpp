--[[
    timerList.lua 计时器 (倒计时结束阻塞执行回调函数)
]]
local linkList = require "linkList"
local timerClass = require "timer"
local timerList = class("timerList")

-- 排序算法
local function compare(newNode, oldNode)
    local newTimer, oldTimer = newNode.timer, oldNode.timer
    return newTimer:getRemainTime() < oldTimer:getRemainTime()
end

local instance = nil
function timerList.sharedInstance()
    if not instance then
        instance = timerList.new()
    end
    return instance
end

function timerList:ctor()
    self.timerList_ = linkList.new("timer")
    self.timerList_:setCompare(compare)
end

----------------API--------------

-- 创建一个timer
-- time： 以秒为单位
-- 计时结束的回调，可以用timerHandler（详见functions.lua）包一层
function timerList:createTimer(time, listener, count, userData)
    --gLog.i("timerList:createTimer", time, listener, count)
    if "number" ~= type(time) then
        gLog.e("timerList:createTimer: time ~= number!")
        return
    end
    if "function" ~= type(listener) then
        gLog.e("timerList:createTimer: listener ~= function")
    end
    if count then
        if "number" == type(count) then
            if count <= 0 then
                gLog.e("timerList:createTimer: count <= 0")
                return
            end
        else
            gLog.e("timerList:createTimer: count ~= number!")
            return
        end
    end

    local timer = timerClass.new(time, listener, count)
    if userData then
        timer.userData = userData
    end

    -- 创建节点
    local node = self.timerList_:newNode(timer, "timer")
    self.timerList_:insert(node)

    return node
end

-- 重启一个timer
function timerList:restartTimer(node, time, count)
    if not node then
        -- node 为空
        gLog.e("timerList:cancelTimer: node == nil!")
        return
    end 
    if node.next or node.pre or node == self.timerList_:front() then
        self.timerList_:remove(node)
    end
    local timer = node.timer
    timer:modifyTime(time)
    timer:setCount(count or 1)

    self.timerList_:insert(node)
    return true
end

-- 取消一个timer
function timerList:cancelTimer(node)
    --gLog.i("timerList:cancelTimer")
    if not node then
        -- node 为空
        gLog.d("timerList:cancelTimer: node == nil!")
        return
    end

    if not node.next and not node.pre and node ~= self.timerList_:front() then
        -- gLog.d("timerList:cancelTimer: invalid node!")
        return
    end

    if node.timer:hasDone() then
        gLog.d("timerList:cancelTimer: node has done!")
        return
    end

    self.timerList_:remove(node)
    return true
end

-- 立即执行
function timerList:dispatchRightNow(node)
    gLog.i("timerList:dispatchRightNow")
    if self:cancelTimer(node) then
        node.timer:dispatchListener()
        if not node.timer:hasDone() then
            node.timer:resetStartTime()
            self.timerList_:insert(node)
        end
    end
end

-- 修改 timer 的计时时间
function timerList:modifyTime(node, time)
    gLog.i("timerList:modifyTime: time = ", time)

    if not node then
        -- node 为空
        gLog.e("timerList:modifyTime: node == nil!")
        return
    end

    if "number" ~= type(time) then
        gLog.e("timerList:modifyTime: time ~= number!")
        return
    end

    if node.timer:hasDone() then
        -- gLog.e("timerList:modifyTime: node has done!")
        return
    end

    self.timerList_:remove(node)
    local timer = node.timer
    timer:modifyTime(time)

    self.timerList_:insert(node)
end

-- 增加时间
function timerList:increaseTime(node, time)
    gLog.i("timerList:increaseTime: time = ", time)

    if not node then
        -- node 为空
        gLog.e("timerList:increaseTime: node == nil!")
        return
    end

    if "number" ~= type(time) then
        gLog.e("timerList:increaseTime: time ~= number!")
        return
    end

    if node.timer:hasDone() then
        gLog.e("timerList:increaseTime: node has done!")
        return
    end

    self.timerList_:remove(node)
    local timer = node.timer
    timer:increaseTime(time)
    self.timerList_:insert(node)
end

-- 减少时间
function timerList:decreaseTime(node, time)
    --gLog.i("timerList:decreaseTime: time = ", time)
    
    if not node then
        -- node 为空
        gLog.e("timerList:decreaseTime: node == nil!")
        return
    end

    if "number" ~= type(time) then
        gLog.e("timerList:decreaseTime: time ~= number!")
        return
    end

    if node.timer:hasDone() then
        gLog.e("timerList:decreaseTime: node has done!")
        return
    end

    self.timerList_:remove(node)
    local timer = node.timer
    timer:decreaseTime(time)
    self.timerList_:insert(node)
end

-- 清空timerList
function timerList:cleanTimers()
    self.timerList_ = nil
end

-- update timer
function timerList:update()
    if not self.timerList_ then
        return
    end
    local curNode = self.timerList_:front()
    if curNode then
        if curNode.timer:hasDone() then
            gLog.e("timerList:update: this node has done!")
            self.timerList_:remove(curNode)
            self:update()
            return
        end
        local remainTime = curNode.timer:getRemainTime()
         --gLog.i("timerList:update() remaintime=",remainTime)
        if remainTime <= 0 then
            self.timerList_:remove(curNode)
            curNode.timer:dispatchListener()
            if not curNode.timer:hasDone() then
                curNode.timer:resetStartTime()
                self.timerList_:insert(curNode)
            end
            self:update()
        end
    end
end

-- 打印链表
function timerList:dump(title)
    self.timerList_:dump(title)
end

-- 打印链表
function timerList:dump2()
    gLog.i("==timerList:dump2 enter==")
    local sizeNum = self.timerList_:size()
    gLog.i("timerList:dump2 sizeNum=", sizeNum)
    if sizeNum > 0 then
        for i = 1, sizeNum, 1 do
            local node = self.timerList_:getNode(i)
            gLog.i("timerList:dump2 i = ", i, ", node =", table2string(node, nil, 2))
        end
    end
    gLog.i("==timerList:dump2 end==")
end

return timerList