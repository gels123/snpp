--[[
	timer.lua 时间队列单元
--]]
local svrFunc = require("svrFunc")
local timer = class("timer")

-- 总计时的时间
timer.totalTime_ = nil
-- 开始时间
timer.startTime_ = nil
-- 回调
timer.listener_ = nil
-- 次数
timer.count_ = nil

-- timer的构造函数
-- time：计时时间，必须为number，以秒为单位
-- listener：计时完后的回调
function timer:ctor(time, listener, count)
    -- 初始化总计时的时间
    self:modifyTime(time)
    -- 初始化开始时间
    self:resetStartTime()
    -- 初始化回调
    self:setListener(listener)
    -- 初始化循环次数，默认为1
    count = count or 1
    self:setCount(count)
    self.userData = nil
end

-----------API----------

-- 获取剩余时间，以秒为单位
-- timer初始化的时候，会记录当前的时间 startTime 
-- 计算剩余时间时，将 curTime（当前时间--osTime） 减去 startTime
-- 这样可以保证计时的准确性
-- curTime 参数可选
function timer:getRemainTime()
    local curTime = svrFunc.systemTime()
    local passTime = curTime - self.startTime_
    local remainTime = self.totalTime_ - passTime
    if remainTime < 0  then
    	remainTime = 0
    end
    return remainTime
end

-- 修改总计时的时间，一般情况是减少时间
function timer:modifyTime(time)
    -- 检查时间参数是否是 number 类型
    assert("number" == type(time), "the time is not a number! it is the " .. type(time))

    -- 设置startTime
    self:resetStartTime()
     
    -- 重置计时时间
    self.totalTime_ = time
end

-- 重置开始时间
function timer:resetStartTime(time)
    self.startTime_ = time or svrFunc.systemTime()
end

-- 获取开始时间
function timer:getStartTime()
    return self.startTime_
end

-- 获取总时间
function timer:getTotalTime()
    return self.totalTime_
end

-- 增加时间
function timer:increaseTime(time)
    -- 检查时间参数是否是 number 类型
    assert("number" == type(time), "the time is not a number! it is the " .. type(time))
    -- 重置计时时间
    self.totalTime_ = self.totalTime_ + time
end

-- 减少时间
function timer:decreaseTime(time)
    -- 检查时间参数是否是 number 类型
    assert("number" == type(time), "the time is not a number! it is the " .. type(time))
    -- 重置计时时间
    self.totalTime_ = self.totalTime_ - time
end

-- 修改回调
function timer:setListener(listener)
    self.listener_ = listener
end

-- 触发回调
function timer:dispatchListener()
    -- 计数减一
    self.count_ = self.count_ - 1
    if "function" == type(self.listener_) then
        -- 触发回调
        self.listener_(self.userData)
    else
        gLog.i("timer listener is not the function!")
    end
end

-- 设置循环次数
function timer:setCount(count)
    if count and count >= 0 then
        self.count_ = count
    end
end

-- 设置循环次数
function timer:getCount()
    return self.count_
end

-- 计数是否完成
function timer:hasDone()
    if self.count_ and self.count_ >= 1 then
        return false
    end
    return true
end

-- 打印
function timer:dump(title)
    gLog.i("========" .. (title or "timer:dump") .. "=======")
    gLog.i("totalTime = ", self.totalTime_)
    gLog.i("startTime = ", self.startTime_)
    gLog.i("remainTime = ", self:getRemainTime())
    gLog.i("listener = ", self.listener_)
    gLog.i("count = ", self.count_)
    gLog.i("\n")
end

return timer