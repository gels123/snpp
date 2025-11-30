--[[
    玩家数据中心缓存(本王国数据则同步本地redis)
--]]
local skynet = require("skynet")
local json = require("json")
local svrFunc = require("svrFunc")
local redisLib = require("redisLib")
local playerDataConfig = require("playerDataConfig")
local playerDataCenter = require("playerDataCenter"):shareInstance()
local playerDataCache = class("playerDataCache")

local gLog, string, type, next, pairs, xpcall = gLog, string, type, next, pairs, xpcall

-- 构造
function playerDataCache:ctor()
    -- 缓存数据
    self.cacheData = {}
    -- 内存数据淘汰(5min)
    self.clearMemTime = dbconf.DEBUG and 30 or 5*60
    self.zset = require("zset").new()
    -- redis数据淘汰(7day)
    self.clearRedisKey = string.format("game-data-clear-%s", playerDataCenter.kid)
    self.clearRedisTime = dbconf.DEBUG and 3600 or 7*86400
    -- sq数据淘汰
    self.zsetSq = require("zset").new()
end

-- 获取内存数据淘汰时间
function playerDataCache:getMemTime()
    local time = svrFunc.systemTime()+self.clearMemTime
    time = time - time%60
    return time
end

-- 获取redis数据淘汰时间
function playerDataCache:getRedisExpireTime()
    return svrFunc.systemTime()+self.clearRedisTime
end

-- 获取内存缓存
function playerDataCache:getMemCache(kid, id, module)
    if kid and id and module then
        local k = string.format("cache%s-%s-%s", kid, module, id)
        if self.cacheData[k] then
            self.zset:add(self:getMemTime(), k) -- 更新内存数据淘汰时间
            return self.cacheData[k]
        end
    else
        gLog.e("playerDataCache:getMemCache error1", kid, id, module)
    end
end

-- 更新内存缓存
function playerDataCache:setMemCache(kid, id, module, data)
    if kid and id and module and data ~= nil then
        local k = string.format("cache%s-%s-%s", kid, module, id)
        self.cacheData[k] = data
        if kid == playerDataCenter.kid then
            self.zset:add(self:getMemTime(), k) -- 更新内存数据淘汰时间
        end
    else
        gLog.e("playerDataCache:setMemCache error1", kid, id, module, data)
    end
end

-- 删除内存缓存
function playerDataCache:delMemCache(kid, id, module)
    if kid and id and module then
        local k = string.format("cache%s-%s-%s", kid, module, id)
        self.cacheData[k] = nil
        self.zset:rem(k) -- 更新数据淘汰时间
    else
        gLog.e("playerDataCache:delMemCache error1", kid, id, module)
    end
end

-- 查询
function playerDataCache:query(kid, id, module)
    -- gLog.d("playerDataCache:query", kid, id, module)
    if kid and id and module then
        -- 先查询内存
        local data = self:getMemCache(kid, id, module)
        -- 若是本王国数据, 再查询本地redis
        if data == nil and kid == playerDataCenter.kid then
            local redisType = playerDataConfig:getRedisType(module)
            local key = redisType.key(kid, id, module)
            local ok
            ok, data = xpcall(function ()
                return redisType.get(key, id, module)
            end, svrFunc.exception)
            if not ok then
                -- 本地redis宕机, 中断业务
                playerDataCenter.playerDataTimer:onRedisReconnect()
                error(string.format("playerDataCache:query error: redis crash %s %s %s", kid, id, module))
            else
                if data ~= nil and data ~= "" then
                    data = json.decode(data) or data
                    -- 更新内存缓存
                    self:setMemCache(kid, id, module, data)
                    -- 更新redis数据淘汰时间
                    local expireTs = self:getRedisExpireTime()
                    redisLib:sendzAdd(self.clearRedisKey, expireTs, key)
                end
            end
        end
        return data
    else
        gLog.e("playerDataCache:query error1", kid, id, module)
    end
end

-- 更新()
function playerDataCache:update(kid, id, module, data, flag)
    gLog.d("playerDataCache:update", kid, id, module, data, flag)
    if kid and id and module and data ~= nil then
        -- 更新内存缓存
        self:setMemCache(kid, id, module, data)
        -- 若是本王国数据, 则更新redis哈希表
        if kid == playerDataCenter.kid then
            local redisType = playerDataConfig:getRedisType(module)
            local key = redisType.key(kid, id, module)
            local str = json.encode(data) or data
            local ok = xpcall(function ()
                return redisType.set(key, id, module, str)
            end, svrFunc.exception)
            if not ok then
                -- 本地redis宕机, 中断业务, 并增加到redis任务队列
                playerDataCenter.playerDataTimer:onRedisReconnect()
                if flag then
                    local taskKey = playerDataCenter:getTaskKey(id, module)
                    playerDataCenter.redisTask:push(taskKey, {cmd = "update", kid = kid, id = id, module = module, data = data, time = skynet.time(),})
                end
                error(string.format("playerDataCache:update error: local redis crash %s %s %s", kid, id, module))
            end
            -- 更新redis数据淘汰时间
            local expireTs = self:getRedisExpireTime()
            redisLib:sendzAdd(self.clearRedisKey, expireTs, key)
        end
    else
        gLog.e("playerDataCache:update error3", kid, id, module, data)
    end
end

-- 删除
function playerDataCache:delete(kid, id, module, custom, flag)
    gLog.d("playerDataCache:delete", kid, id, module, custom, flag)
    if kid and id and module then
        -- 删除内存缓存
        self:delMemCache(kid, id, module)
        -- 若是本王国数据, 则删除redis哈希表
        if kid == playerDataCenter.kid then
            local redisType = playerDataConfig:getRedisType(module)
            local key = redisType.key(kid, id, module)
            local ok = xpcall(function ()
                return redisType.del(key, id, module)
            end, svrFunc.exception)
            if not ok then
                -- 本地redis宕机, 中断业务, 并增加到redis任务队列
                playerDataCenter.playerDataTimer:onRedisReconnect()
                if flag then
                    local taskKey = playerDataCenter:getTaskKey(id, module)
                    playerDataCenter.redisTask:push(taskKey, {cmd = "delete", kid = kid, id = id, module = module, custom = custom, time = skynet.time(),})
                end
                error(string.format("playerDataCache:delete error: local redis crash %s %s %s", kid, id, module))
            end
            -- 更新redis数据淘汰时间
            redisLib:sendzRem(self.clearRedisKey, key)
        end
    else
        gLog.e("playerDataCache:delete error1", kid, id, module)
    end
end

-- 定时清理内存缓存
function playerDataCache:onTimerClearCache()
    local time = svrFunc.systemTime()
    --gLog.d("== playerDataCache:onTimerClearCache begin =", time)
    local count, isEnd = 0, false
    while(true) do
        local keyList = self.zset:range(1, 500) or {}
        --gLog.dump(keyList, "playerDataCache:onTimerClearCache keyList=", 10)
        for _,key in pairs(keyList) do
            if self.zset:score(key) > time then
                isEnd = true
                break
            end
            count = count + 1
            self.cacheData[key] = nil
            self.zset:rem(key)
            --gLog.d("playerDataCache:onTimerClearCache do=", count, key)
        end
        if #keyList < 500 or isEnd or count >= 50000 then
            break
        end
        skynet.sleep(2)
    end
    gLog.d("== playerDataCache:onTimerClearCache end =", time, count)
    --gLog.dump(self, "playerDataCache:onTimerClearCache self=")
end

-- 定时清理redis
function playerDataCache:onTimerClearRedis()
    local time = svrFunc.systemTime()
    --gLog.i("== playerDataCache:onTimerClearRedis begin =", time)
    local count, isEnd, key, score, batch = 0, false, nil, nil, 200
    while(true) do
        local keyList = redisLib:zRange(self.clearRedisKey, 0, batch, true)
        if not keyList or #keyList <= 0 then
            break
        end
        --gLog.dump(keyList, "playerDataCache:onTimerClearRedis keyList=", 10)
        for i=1,#keyList,2 do
            key, score = tostring(keyList[i]), tonumber(keyList[i+1])
            if not score or score > time then
                isEnd = true
                break
            end
            count = count + 1
            redisLib:sendDelete(key)
            redisLib:sendzRem(self.clearRedisKey, key)
            --gLog.d("playerDataCache:onTimerClearRedis do=", count, key)
        end
        if #keyList < batch or isEnd or count >= 50000 then
            break
        end
        skynet.sleep(2)
    end
    gLog.i("== playerDataCache:onTimerClearRedis end =", time, count)
end

function playerDataCache:getClearRedisKey()
    return self.clearRedisKey
end

function playerDataCache:addZsetSq(key)
    self.zsetSq:add(self:getMemTime(), key)
end

-- 定时清理sq数据
function playerDataCache:onTimerClearSq()
    local time = svrFunc.systemTime()
    --gLog.d("== playerDataCache:onTimerClearSq begin =", time)
    local count, isEnd = 0, false
    while(true) do
        local keyList = self.zsetSq:range(1, 500) or {}
        --gLog.dump(keyList, "playerDataCache:onTimerClearSq keyList=", 10)
        for _,key in pairs(keyList) do
            if self.zsetSq:score(key) > time then
                isEnd = true
                break
            end
            count = count + 1
            self.zsetSq:rem(key)
            playerDataCenter:delSq(key)
            --gLog.d("playerDataCache:onTimerClearSq do=", count, key)
        end
        if #keyList < 500 or isEnd or count >= 50000 then
            break
        end
        skynet.sleep(2)
    end
    gLog.d("== playerDataCache:onTimerClearSq end =", time, count)
    --gLog.dump(playerDataCenter, "playerDataCache:onTimerClearSq playerDataCenter=")
end

-- 打印
function playerDataCache:dump()
    gLog.dump(self.cacheData, "playerDataCache:dump cacheData=", 10)
    gLog.d("playerDataCache:dump zset count=", self.zset:count())
end

return playerDataCache