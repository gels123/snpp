--[[
	玩家数据中心定时器
]]
local skynet = require("skynet")
local svrFunc = require("svrFunc")
local svrAddrMgr = require("svrAddrMgr")
local playerDataCenter = require("playerDataCenter"):shareInstance()
local playerDataTimer = class("playerDataTimer", cc.mvc.ModelBase)

-- 倒计时: 定时处理redis更新任务列表
local tDealRedisTask = "tDealRedisTask"
-- 倒计时: 定时处理db更新任务列表
local tDealDbTask = "tDealDbTask"
-- 倒计时: 定时清理缓存
local tClearCache = "tClearCache"
-- 倒计时: 定时清理redis
local tClearRedis = "tClearRedis"
-- 倒计时: 定时db断线重连
local tDbReconnect = "tDbReconnect"
-- 倒计时: 定时redis断线重连
local tRedisReconnect = "tRedisReconnect"

function playerDataTimer:ctor()
	playerDataTimer.super.ctor(self)

    -- 时间队列
    self.queue = {}

    -- 处理db更新任务列表间隔
    self.dealTaskInv = dbconf.DEBUG and 20 or 60
    -- 清理缓存间隔
    self.clearCacheInv = dbconf.DEBUG and 13*60 or 33*60
    -- 清理redis间隔
    self.clearRedisInv = dbconf.DEBUG and 3600 or 86400
    -- db/redis断线重连间隔
    self.reconnectInv = 7
    -- db断线重连中
    self.dbReconnect = nil

	-- 注册倒计时回调
    self:addEventListener(tDealRedisTask, handler(self, self.onDealRedisTask))
    self:addEventListener(tDealDbTask, handler(self, self.onDealDbTask))
    self:addEventListener(tClearCache, handler(self, self.onTimerClearCache))
    self:addEventListener(tClearRedis, handler(self, self.onTimerClearRedis))
    self:addEventListener(tDbReconnect, handler(self, self.onDbReconnect))
	self:addEventListener(tRedisReconnect, handler(self, self.onRedisReconnect))
end

-- 初始化
function playerDataTimer:init()
    -- 添加倒计时: 定时处理redis更新任务列表
    self:addQueue(tDealRedisTask, svrFunc.systemTime()+self.dealTaskInv)
    -- 添加倒计时: 定时处理db更新任务列表
    self:addQueue(tDealDbTask, svrFunc.systemTime()+self.dealTaskInv)
    -- 添加倒计时: 定时清理缓存
    self:addQueue(tClearCache, svrFunc.systemTime()+self.clearCacheInv)
    -- 添加倒计时: 定时清理redis
    self:addQueue(tClearRedis, svrFunc.systemTime()+self.clearRedisInv)
end

-- 停服
function playerDataTimer:stop()
    -- 加快倒计时
    self.reconnectInv = 5
    self.dealTaskInv = 1
    --
    self:onRedisReconnect()
    self:onDbReconnect()
    -- 触发倒计时
    local qtypes = {tRedisReconnect, tDbReconnect, tDealRedisTask, tDealDbTask}
    for _,qtype in pairs(qtypes) do
        skynet.fork(function()
            local timerId = self.queue[qtype] and self.queue[qtype].timerId
            if timerId then
                playerDataCenter.myTimer:dispatchRightNow(timerId)
            end
        end)
    end
end

--查询时间队列
function playerDataTimer:queryQueue(qtype)
    return self.queue[tostring(qtype)]
end

--移除时间队列
function playerDataTimer:removeQueue(qtype)
	qtype = tostring(qtype)
    local queue = self:queryQueue(qtype)
    if queue and queue.timerId then
		playerDataCenter.myTimer:cancelTimer(queue.timerId)
		self.queue[qtype] = nil
        gLog.i("playerDataTimer:removeQueue qtype=", qtype)
    end
end

--增加时间队列
function playerDataTimer:addQueue(qtype, endTime, data)
    -- gLog.d("playerDataTimer:addQueue", qtype, endTime, transformTableToSrting(data))
    qtype = tostring(qtype)
    local queue = self:queryQueue(qtype)
    if queue then
        self:removeQueue(qtype)
    end
    --gLog.i("playerDataTimer:addQueue qtype", qtype, endTime)
    local queue = {
        qtype = qtype,
        endTime = endTime,
        data = data,
        timerId = nil,
    }
    local function dispatchQueueEvent()
        self.queue[qtype] = nil
        self:dispatchEvent({name = qtype, data = data})
    end
    queue.timerId = playerDataCenter.myTimer:schedule(timerHandler(dispatchQueueEvent), endTime)
    self.queue[qtype] = queue
end

-- 倒计时回调: 定时处理db更新任务列表
function playerDataTimer:onDealRedisTask(event)
    -- 定时处理db更新任务列表
    xpcall(function()
        playerDataCenter:onDealRedisTask()
    end, svrFunc.exception)
    -- 添加倒计时: 定时处理db更新任务列表
    self:addQueue(tDealRedisTask, svrFunc.systemTime()+self.dealTaskInv)
end

-- 倒计时回调: 定时处理db更新任务列表
function playerDataTimer:onDealDbTask(event)
    -- 定时处理db更新任务列表
    xpcall(function()
        playerDataCenter:onDealDbTask()
    end, svrFunc.exception)
    -- 添加倒计时: 定时处理db更新任务列表
    self:addQueue(tDealDbTask, svrFunc.systemTime()+self.dealTaskInv)
end

-- 倒计时回调: 定时清理缓存
function playerDataTimer:onTimerClearCache(event)
    -- 定时清理缓存
    xpcall(function()
        playerDataCenter.playerDataCache:onTimerClearCache()
    end, svrFunc.exception)
    -- 定时清理sq数据
    xpcall(function()
        playerDataCenter.playerDataCache:onTimerClearSq()
    end, svrFunc.exception)
    -- 添加倒计时: 定时清理缓存
    self:addQueue(tClearCache, svrFunc.systemTime()+self.clearCacheInv)
end

-- 倒计时回调: 定时清理redis
function playerDataTimer:onTimerClearRedis(event)
    -- 定时清理缓存
    xpcall(function()
        playerDataCenter.playerDataCache:onTimerClearRedis()
    end, svrFunc.exception)
    -- 添加倒计时: 定时清理缓存
    self:addQueue(tClearRedis, svrFunc.systemTime()+self.clearRedisInv)
end

-- 倒计时: db断线重连
function playerDataTimer:onDbReconnect()
    if self.dbReconnect then
        return
    end
    self.dbReconnect = true
    local pok, ok = playerDataCenter.dbWrap:onDbReconnect()
    if pok and ok then
        gLog.i("playerDataTimer:onDbReconnect ignore pok=", pok, "ok=", ok)
        self.dbReconnect = nil
    else
        -- 断线重连失败, db有重连机制, 固本处屏蔽
        -- self:addQueue(tDbReconnect, svrFunc.systemTime()+self.reconnectInv)
    end
end

-- 倒计时回调: redis断线重连
function playerDataTimer:onRedisReconnect()
    if self.redisReconnect then -- redis已有重连逻辑
        return
    end
    self.redisReconnect = true

    local redisSvr = svrAddrMgr.getSvr(svrAddrMgr.redisSvr)
    local pok, ok = xpcall(function ()
        return skynet.call(redisSvr, "lua", "ping")
    end, svrFunc.exception)
    if pok and ok then
        gLog.i("playerDataTimer:onRedisReconnect ignore pok=", pok, "ok=", ok)
        self.redisReconnect = nil
        return
    end

    pok, ok = xpcall(function ()
        return skynet.call(redisSvr, "lua", "reconnect", dbconf.redis)
    end, svrFunc.exception)
    gLog.i("playerDataTimer:onRedisReconnect pok=", pok, "ok=", ok)
    if pok and ok then
        -- 断线重连成功
        self.redisReconnect = nil
    else
        -- 断线重连失败, redis有重连机制, 固本处屏蔽
        -- self:addQueue(tRedisReconnect, svrFunc.systemTime()+self.reconnectInv)
    end
end

-- redis是否连接成功
function playerDataTimer:isRedisAlive()
    local redisSvr = svrAddrMgr.getSvr(svrAddrMgr.redisSvr)
    local ret = skynet.call(redisSvr, "lua", "isConnected")
    return ret
end

---- 立即执行一次数据落地
--function playerDataTimer:saveNow()
--    if self.queue[tDealRedisTask] then
--        gLog.d("playerDataTimer:saveNow dealRedisTask", playerDataCenter.idx)
--        playerDataCenter.myTimer:dispatchRightNow(self.queue[tDealRedisTask].timerId)
--    end
--    if self.queue[tDealDbTask] then
--        gLog.d("playerDataTimer:saveNow dealDbTask", playerDataCenter.idx)
--        playerDataCenter.myTimer:dispatchRightNow(self.queue[tDealDbTask].timerId)
--    end
--end

return playerDataTimer
