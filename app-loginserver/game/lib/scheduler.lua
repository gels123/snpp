--[[
    定时器(弃用)
]]
local skynet = require("skynet")
local scheduler = class("schedule")

local defaultRefreshTime = 1

local schedulerCount = 0

------------------API--------------------
function scheduler.create(fun, time)
    local sche = scheduler.new()
    sche:scheduleUpdate(fun)
    sche:setRefreshTime(time)
    return sche
end

-- 获取定时器数量
function scheduler.getSchedulerCount()
    return schedulerCount
end

-- 设置刷新函数
function scheduler:scheduleUpdate(fun)
    if "function" == type(fun) then
        table.insert(self.call_list, fun)
    end
end

-- 设置定时器刷新时间
function scheduler:setRefreshTime(time)
    if "number" == type(time) and time > 0 then
        self.refreshTime_ = time
    end
end

-- 获取定时器刷新时间
function scheduler:getRefreshTime()
    return self.refreshTime_
end

-- 启动计时器
function scheduler:start()
    self.continue = true
    if self.schedulerCo then
        skynet.wakeup(self.schedulerCo)
    end
end

-- 暂停计时器
function scheduler:pause()
    self.continue = false
end

-- 刷新
function scheduler:update()
    for i, call in ipairs(self.call_list) do
        xpcall(call, svrFunc.exception)
    end
end

-- 是否正在运行
function scheduler:isRunning()
    return self.continue
end

----------------------------------------

local function coFun(self)
    while true do
        if self.continue then
            skynet.sleep(self:getRefreshTime() * 100)
            self:update()
        else
            skynet.wait()
        end
    end
end

function scheduler:ctor()
    schedulerCount = schedulerCount + 1
    -- print("scheduler.create( fun, time )", schedulerCount)
    self:setRefreshTime(defaultRefreshTime)
    -- 是否继续运行，默认未不继续
    self.continue = false
    self.call_list = {}
    -- 定时器协程
    self.schedulerCo = skynet.fork(coFun, self)
end

return scheduler