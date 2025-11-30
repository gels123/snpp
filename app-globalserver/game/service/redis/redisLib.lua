--[[
    本地redis接口
]]
local skynet = require "skynet"
local svrAddrMgr = require "svrAddrMgr"
local redisLib = class("redisLib")

--[[
    获取redis服务地址
]]
function redisLib:getAddress()
    return svrAddrMgr.getSvr(svrAddrMgr.redisSvr)
end

--[[
    call阻塞调用
]]
function redisLib:call(...)
    return skynet.call(self:getAddress(), "lua", ...)
end

--[[
    call非阻塞调用
]]
function redisLib:send(...)
    skynet.send(self:getAddress(), "lua", ...)
end

--[[
    测试redis连接
]]
function redisLib:ping()
    return self:call("ping")
end

--[[
    根据key判断是否存在value
]]
function redisLib:exists(key)
    return self:call("exists", key)
end

--[[
    设置键值
]]
function redisLib:set(key, value)
    return self:call("set", key, value)
end

--[[
    设置键值
]]
function redisLib:sendSet(key, value)
    return self:send("set", key, value)
end

--[[
    根据key获得value
]]
function redisLib:get(key)
    return self:call("get", key)
end

--[[
    带生存时间的写入值
]]
function redisLib:setex(key, time, value)
    return self:call("setex", key, time, value)
end

--[[
    判断是否重复的写入值, 如果已经写入则不修改
]]
function redisLib:setnx(key, value)
    return self:call("setnx", key, value)
end

--[[
    判断是否重复的写入值, 如果已经写入则不修改, 否者写入并设置生存时间
]]
function redisLib:setexnx(key, value, seconds)
    return self:call("setexnx", key, value, seconds)
end

--[[
    删除指定的key
    key 可以是单个也可以是一个table 返回被删除的个数
]]
function redisLib:delete(key)
    return self:call("delete", key)
end

--[[
    删除指定的key
    key 可以是单个也可以是一个table 返回被删除的个数
]]
function redisLib:sendDelete(key)
    self:send("delete", key)
end

--[[
    名称为key的集合中查找是否有value元素，有ture 没有false
]]
function redisLib:sismember(key, value)
    return self:call("sismember", key, value)
end

--[[
    向名称为key的set中添加元素value,如果value存在, 不写入, return false
]]
function redisLib:sAdd(key, value)
    return self:call("sAdd", key, value)
end

--[[
    删除名称为key的set中的元素value
]]
function redisLib:sRem(key, value)
    return self:call("sRem", key, value)
end

--[[
    删除名称为key的set中的元素value
]]
function redisLib:sMove(seckey, dstkey, value)
    return self:call("sMove", seckey, dstkey, value)
end

--[[
    返回名称为key的set的所有元素
]]
function redisLib:sMembers(key)
    return self:call("sMembers", key)
end

-->>>>>>>>>>>>>>>>>>>>list相关操作>>>>>>>>>>>>>>>>>>>>

--[[
    在名称为key的list左边（头）添加一个值为value的 元素
]]
function redisLib:lPush(key, value)
    return self:call("lPush", key, value)
end

--[[
    在名称为key的list右边（尾）添加一个值为value的 元素
]]
function redisLib:rPush(key, value)
    return self:call("rPush", key, value)
end

--[[
    在名称为key的list左边（头）添加一个值为value的 元素
]]
function redisLib:lPushx(key, value)
    return self:call("lPushx", key, value)
end

--[[
    在名称为key的list右边（尾）添加一个值为value的 元素
]]
function redisLib:rPushx(key, value)
    return self:call("rPushx", key, value)
end

--[[
    输出名称为key的list左(头)起/右（尾）起的第一个元素，删除该元素
]]
function redisLib:lPop(key)
    return self:call("lPop", key)
end

--[[
    输出名称为key的list左(头)起/右（尾）起的第一个元素，删除该元素
]]
function redisLib:rPop(key)
    return self:call("rPop", key)
end

--[[
    返回名称为key的list中index位置的元素
]]
function redisLib:lIndex(key, index)
    return self:call("lIndex", key, index)
end

--[[
    返回名称为key的list中index位置的元素
]]
function redisLib:lSet(key, index, value)
    return self:call("lSet", key, index, value)
end

--[[
    返回名称为key的list中start至end之间的元素（end为 -1，返回所有）
]]
function redisLib:lRange(key, startIndex, endIndex)
    return self:call("lRange", key, startIndex, endIndex)
end

--[[
    返回key所对应的list元素个数
]]
function redisLib:lLen(key)
    return self:call("lLen", key)
end

--[[
    截取名称为key的list，保留start至end之间的元素
]]
function redisLib:lTrim(key, startIndex, endIndex)
    return self:call("lTrim", key, startIndex, endIndex)
end

--[[
    删除count个名称为key的list中值为value的元素。count为0，删除所有值为value的元素，count>0从头至尾删除count个值为value的元素，count<0从尾到头删除|count|个值为value的元素
]]
function redisLib:lRem(key, value, count)
    return self:call("lRem", key, value, count)
end

--[[
    在名称为为key的list中，找到值为pivot 的value，并根据参数Redis::BEFORE | Redis::AFTER，来确定，newvalue 是放在 pivot 的前面，或者后面。如果key不存在，不会插入，如果 pivot不存在，return -1
]]
function redisLib:lInsert(key, insertMode, value, newValue)
    return self:call("lInsert", key, insertMode, value, newValue)
end

-->>>>>>>>>>>>>>hash操作>>>>>>>>>>>>>>>>
--[[
    向名称为h的hash中添加元素key—>value
]]
function redisLib:hSet(h, key, value)
    return self:call("hSet", h, key, value)
end

--[[
    向名称为h的hash中添加元素key—>value
]]
function redisLib:sendHSet(h, key, value)
    self:send("hSet", h, key, value)
end

--[[
    返回名称为h的hash中key对应的value
]]
function redisLib:hGet(h, key)
    return self:call("hGet", h, key)
end

--[[
    返回名称为h的hash中元素个数
]]
function redisLib:hLen(h)
    return self:call("hLen", h)
end

--[[
    删除名称为h的hash中键为key的域
]]
function redisLib:hDel(h, key)
    return self:call("hDel", h, key)
end

--[[
    删除名称为h的hash中键为key的域
]]
function redisLib:sendHDel(h, key)
    self:send("hDel", h, key)
end

--[[
  返回名称为key的hash中所有键
]]
function redisLib:hKeys(h)
    return self:call("hKeys", h)
end
--[[
    返回名称为h的hash中所有键对应的value
]]
function redisLib:hVals(h)
    return self:call("hVals", h)
end

--[[
    返回名称为h的hash中所有的键（key）及其对应的value
]]
function redisLib:hGetAll(h)
    return self:call("hGetAll", h)
end

--[[
    名称为h的hash中是否存在键名字为key的域
]]
function redisLib:hExists(h, key)
    return self:call("hExists", h, key)
end

--[[
    将名称为h的hash中key的value增加number
]]
function redisLib:hIncrBy(h, key, number)
    return self:call("hIncrBy", h, key, number)
end

--[[
    向名称为key的hash中批量添加元素
]]
function redisLib:hMset(h, table)
    return self:call("hMset", h, table)
end

--[[
    返回名称为h的hash中keytable中key对应的value
]]
function redisLib:hMGet(h, keyTable)
    return self:call("hMGet", h, keyTable)
end

--[[
    给key重命名
]]
function redisLib:rename(key, newKey)
    return self:call("rename", key, newKey)
end

--[[
    设定一个key的活动时间（s）
]]
function redisLib:setTimeout(key, time)
    return self:call("setTimeout", key, time)
end

--[[
    key存活到一个unix时间戳时间
]]
function redisLib:expireAt(key, time)
    return self:call("expireAt", key, time)
end

--[[
    返回满足给定pattern的所有key
]]
function redisLib:keys(key)
    return self:call("keys", key)
end

function redisLib:dbSize()
    return self:call("dbSize")
end

--[[
    根据条件获取结果集
]]
function redisLib:queryResult(conditions, key)
    return self:call("queryResult", conditions, key)
end

--[[
    把数据放在redis
]]
function redisLib:setResult(key, result)
    return self:call("setResult", key, result)
end

--[[
    加密key
]]
function redisLib:encryptKey(conditions)
    return self:call("encryptKey", conditions)
end

-----
-- 添加一个成员到有序集合,或者如果它已经存在更新其分数
function redisLib:zAdd(key, score, member)
    return self:call("zAdd", key, score, member)
end

-- 添加一个成员到有序集合,或者如果它已经存在更新其分数
function redisLib:sendzAdd(key, score, member)
    self:send("zAdd", key, score, member)
end

-- 删除一个成员到有序集合
function redisLib:zRem(key, member)
    return self:call("zRem", key, member)
end

-- 删除一个成员到有序集合
function redisLib:sendzRem(key, member)
    self:send("zRem", key, member)
end

-- 确定一个有序集合成员的索引，以分数排序，从高分到低分
function redisLib:zRevRank(key, member)
    return self:call("zRevRank", key, member)
end

-- 得到的有序集合成员的数量
function redisLib:zCard(key)
    return self:call("zCard", key)
end

-- 返回一个成员范围的有序集合，通过索引，以分数排序，从低分到高分
function redisLib:zRange(key, start, stop, isWithscores)
    return self:call("zRange", key, start, stop, isWithscores)
end

-- 返回一个成员范围的有序集合，通过索引，以分数排序，从高分到低分
function redisLib:zRevRange(key, start, stop, isWithscores)
    return self:call("zRevRange", key, start, stop, isWithscores)
end

--[[
SCAN 命令是一个基于游标的迭代器，每次被调用之后， 都会向用户返回一个新的游标， 用户在下次迭代时需要使用这个新游标作为 SCAN 命令的游标参数， 以此来延续之前的迭代过程。
SCAN 返回一个包含两个元素的数组， 第一个元素是用于进行下一次迭代的新游标， 而第二个元素则是一个数组， 这个数组中包含了所有被迭代的元素。如果新游标返回 0 表示迭代已结束。
示例:
    local scanFunc = redisLib:scan(0, "*", 200)
    local ok, ret = false, nil
    while true do
        ok, ret = scanFunc()
        if ret then
            for _, id in pairs(ret) do
                gLog.d("=scan key=", id)
            end
        end
        if not ok then
            break
        end
    end
]]
function redisLib:scan(cursor, pattern, count)
    local params = {cursor}
    if pattern then
        table.insert(params, "MATCH")
        table.insert(params, pattern)
    end
    if count then
        table.insert(params, "COUNT")
        table.insert(params, count) 
    end
    local continue = true
    local scanfunc = function()
        local ret = self:call("scan", table.unpack(params))
        if ret and next(ret) then
            if ret[1] == "0" then
                continue = false
            else
                params[1] = ret[1]
            end
            return continue, ret[2]
        end
        return nil
    end
    return scanfunc
end

--[[
    订阅频道
    eg:
        local ok = publicRedisLib:subscribe(dbconf.publicRedis, playerDataLib.channel)
        if ok then
            local f = function()
                local data, channel = publicRedisLib:message(playerDataLib.channel)
                gLog.d("playerDataCenter:subscribe receive", channel, data)
            end
            skynet.fork(function(f)
                while true do
                    f()
                end
            end, f)
        end
]]
function redisLib:subscribe(conf, channel)
    return self:call("subscribe", conf, channel)
end

--[[
    接收频道消息
]]
function redisLib:message(channel)
    return self:call("message", channel)
end

--[[
    取消订阅频道
]]
function redisLib:unsubscribe(channel)
    return self:call("unsubscribe", channel)
end

--[[
    发布
]]
function redisLib:publish(channel, ...)
    return self:call("publish", channel, ...)
end

return redisLib