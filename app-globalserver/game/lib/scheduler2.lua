--[[
    计时器
    示例:
        local scheduler2 = require("scheduler2").new()
        local curtime = now()
        for i=1,10 do
            local ID = scheduler2:schedule(function ( param )
                -- skynet.sleep(2*100)
                print("time out=",param,curtime+i,now())
            end,curtime+i,"test" .. i)
            scheduler2:delay(ID,1)
        end
        scheduler2:start()
--]]
local skynet = require("skynet")
local zset = require("zset")
local scheduler2 = class("scheduler2")

local now = function()
    return math.floor(skynet.time())
end

local count = 0

function scheduler2.create(fun, time)
    local sche = scheduler2.new()
    sche:scheduleUpdate(fun)
    sche:setRefreshTime(time)
    return sche
end

-- 获取实例数量
function scheduler2:getSchedulerCount()
    return count
end

-- 设置刷新函数
function scheduler2:schedule(fun,endtime,param,repeats)
    if "function" == type(fun) then
        assert(self.list[self.ID] == nil, "timer ID is duplicate")
        local retID = self.ID
        local ID = tostring(self.ID)
        -- item[1] = 回调函数,item[2] = 参数,item[3] = 是否重复,item[4] = 定时间隔
        local nowTime = now()
        local interval = endtime - nowTime
        -- if interval <= 0 then 
        --     gLog.e("error interval <= 0", interval, endtime, nowTime)
        -- end
        if repeats then assert(interval > 0, "if repeats then interval must > 0") end
        self.list[ID] = {fun,param,repeats,interval}
        self.zset:add(endtime,ID)
        self.ID = self.ID + 1
        return retID
    end
end

-- 设置刷新函数
function scheduler2:repeatSchedule(fun,interval,param)
    if "function" == type(fun) then
        assert(self.list[self.ID] == nil,"timer ID is duplicate")
        local retID = self.ID
        local ID = tostring(self.ID)
        -- item[1] = 回调函数,item[2] = 参数,item[3] = 是否重复,item[4] = 定时间隔
        assert(interval>0,"if repeats then interval must > 0")
        local endtime = now() + interval
        self.list[ID] = {fun,param,true,interval}
        self.zset:add(endtime,ID)
        self.ID = self.ID + 1
        return retID
    end
end

-- 设置定时器刷新时间
function scheduler2:setRefreshTime(time)
    if "number" == type(time) and time > 0 then
        self.refreshTime = time
    end
end

-- 获取定时器刷新时间
function scheduler2:getRefreshTime()
    return self.refreshTime
end

-- 启动计时器
function scheduler2:start()
    if not self.continue then
        self.continue = true
        if self.schedulerCo then
            skynet.wakeup(self.schedulerCo)
        end
    end
end

-- 暂停计时器
function scheduler2:pause()
    self.continue = false
end

-- 刷新
function scheduler2:update()
    local ret = self.zset:range_by_score(0, now())
    for _, ID in ipairs(ret) do
        local item = self.list[ID]
        if item then
            if not item[3] then
                self.list[ID] = nil
                self.zset:rem(ID)
            elseif item[4] then --重复性计时器
                if item[4] ~= 1 then -- 每秒的无需每次都添加
                    self.zset:add(now() + item[4],ID)
                end
            end
            -- print("ID=",ID,now())
            skynet.fork(item[1], item[2])
        end
    end
end

-- 更新计时器ID到某一时刻
function scheduler2:reset(schedulerID, newEndtime)
    if schedulerID and newEndtime and type(newEndtime) == "number" then
        local ID = tostring(schedulerID)
        local score = self.zset:score(ID)
        if score ~= newEndtime then
            self.zset:add(newEndtime,ID)
        end
        return true
    end
    return false
end

-- 加速计时器ID,提前n秒结束
function scheduler2:speedup(schedulerID, second)
    if schedulerID and second and type(second) == "number" and second > 0 then
        local ID = tostring(schedulerID)
        local endtime = self.zset:score(ID)
        if endtime then
            self.zset:add(endtime-second,ID)
            return true
        end
    end
    return false
end

-- 加速计时器ID,延迟n秒结束
function scheduler2:delay(schedulerID, second)
    if schedulerID and second and type(second) == "number" and second > 0 then
        local ID = tostring(schedulerID)
        local endtime = self.zset:score(ID)
        if endtime then
            self.zset:add(endtime+second,ID)
            return true
        end
    end
    return false
end

-- 是否正在运行
function scheduler2:isRunning()
    return self.continue
end

-- 停止计时器ID
function scheduler2:stop(schedulerID)
    if schedulerID then
        local ID = tostring(schedulerID)
        local item = self.list[ID]
        if item then
            self.list[ID] = nil
            self.zset:rem(ID)
            return true
        end
    end
    return false
end

-- 立即执行某一计时器ID(阻塞调用)
function scheduler2:dispatchRightNow(schedulerID)
    local ID = tostring(schedulerID)
    local item = self.list[ID]
    if item then
        -- 立马从定时列表删除
        self.zset:rem(ID)
        local func = item[1]
        -- 回调
        xpcall(func, svrFunc.exception, item[2])
        -- 列表置空
        self.list[ID] = nil
        return true
    end
    return false
end

-- 清空所有计时器
function scheduler2:clear()
    self.zset:limit(0)
    self.list = {}
end

local function coFun(self)
    while true do
        -- gLog.d("==scheduler2 coFun==", self.name, self.zset:count())
        if self.continue then
            skynet.sleep(self:getRefreshTime() * 100)
            self:update()
        else
            skynet.wait()
        end
    end
end

function scheduler2:ctor(name)
    self.name = name
    -- 是否继续运行，默认未不继续
    self.continue = false
    self.list = {}
    self.ID = 1
    self.zset = zset.new()
    self.refreshTime = 1
    -- 定时器协程
    self.schedulerCo = skynet.fork(coFun, self)
    -- 实例数量+1
    count = count + 1
end

return scheduler2