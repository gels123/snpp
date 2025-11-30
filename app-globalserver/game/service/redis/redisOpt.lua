--[[  
    优点  
    一、实例控制  
    单例模式会阻止其他对象实例化其自己的单例对象的副本，从而确保所有对象都访问唯一实例。  
    二、灵活性  
    因为类控制了实例化过程，所以类可以灵活更改实例化过程。  
  
    缺点  
    一、开销  
    虽然数量很少，但如果每次对象请求引用时都要检查是否存在类的实例，将仍然需要一些开销。可以通过使用静态初始化解决此问题。  
    二、可能的开发混淆  
    使用单例对象（尤其在类库中定义的对象）时，开发人员必须记住自己不能使用new关键字实例化对象。因为可能无法访问库源代码，因此应用程序开发人员可能会意外发现自己无法直接实例化此类。  
    三、对象生存期  
    不能解决删除单个对象的问题。在提供内存管理的语言中（例如基于.NET Framework的语言），只有单例类能够导致实例被取消分配，因为它包含对该实例的私有引用。在某些语言中（如 C++），其他类可以删除对象实例，但这样会导致单例类中出现悬浮引用。  
  
]]
local skynet = require("skynet")
local redis = require ("skynet.db.redis")
local crypt = require ("skynet.crypt")
local json = require ("json")
local redisOpt = class("redisOpt")

local db, refCount = nil, 0

local errors =
{
    "redis not Initialization",
    "key is nil",
    "value is nil",
}

--[[
    连接redis
]]
function redisOpt.connect(conf)
    assert(conf, "redisOpt.connect error: conf is invalid")
    if db then
        redisOpt.disconnect()
        db = nil
    end
    db = redis.connect(conf)
    refCount = refCount + 1
    return true
end

--[[
    断开连接
]]
function redisOpt.disconnect()
    if db then
        db:disconnect()
        db = nil
        refCount = refCount - 1
    end
end

--[[
    ping
]]
function redisOpt.ping()
    return db:ping()
end

--[[
    杀死服务
]]
function redisOpt.kill()
    gLog.i("redisOpt.kill")
    skynet.exit()
end

--[[
    参数断言判断
]]
local function checkParams(...)
    for i = 1, select("#", ...) do
        assert(select(i, ...) ~= nil, errors[i])
    end
end

--[[
    根据key是否存在value
]]
function redisOpt.exists(key)
    checkParams(db, key)
    return db:exists(key)
end

--[[
    设置key=>value
]]
function redisOpt.set(key, value)
    checkParams(db, key, value)
    return db:set(key, value)
end

--[[
    根据key获得value
]]
function redisOpt.get(key)
    checkParams(db, key)
    return db:get(key)
end

--[[
    自减一
]]
function redisOpt.decr(key)
    checkParams(db, key)
    return db:decr(key)
end

--[[
    自减一
]]
function redisOpt.decrby(key, decrement)
    checkParams(db, key, decrement)
    return db:decrby(key, decrement)
end

--[[
    自增++
]]
function redisOpt.incr(key)
    checkParams(db, key)
    return db:incr(key)
end

--[[
    自增++
]]
function redisOpt.incrby(key, increment)
    checkParams(db, key, increment)
    return db:incrby(key, increment)
end

--[[
    setex 带生存时间的写入值
]]
function redisOpt.setex(key, time, value)
     checkParams(db, key, time, value)
     db:setex(key, time, value)
end

--[[
    判断是否重复的，写入值如果已经写入则不修改
]]
function redisOpt.setnx(key, value)
     checkParams(db, key, value)
     db:setnx(key,value)
end

--[[
    判断是否重复的写入值, 如果已经写入则不修改, 否者写入并设置生存时间 set key value EX seconds NX
    ret: "OK" or nil
]]
function redisOpt.setexnx(key, value, seconds)
    checkParams(db, key, value)
    local ret = db:set(key, value, "EX", seconds, "NX")
    -- gLog.d(ret, "redisOpt.setexnx", key, value, seconds)
    return ret
end

--[[
    删除指定的key
    key 可以是单个也可以是一个table 返回被删除的个数
]]
function redisOpt.delete(key)
    checkParams(db, key)
    return db:del(key)
end

--[[
    名称为key的集合中查找是否有value元素，有ture 没有 false
]]
function redisOpt.sismember(key, value)
     checkParams(db, key, value)
     return db:sismember(key, value)
end

--[[
    向名称为key的set中添加元素value,如果value存在，不写入，return false
]]
function redisOpt.sAdd(key, value)
    checkParams(db, key, value)
    return db:sAdd(key, value)
end

--[[
    删除名称为key的set中的元素value
]]
function redisOpt.sRem(key, value)
    checkParams(db, key, value)
    return db:sRem(key, value)
end

--[[
    删除名称为key的set中的元素value
]]
function redisOpt.sMove(seckey, dstkey, value)
    return db:sMove(seckey, dstkey, value)
end

--[[
    返回名称为key的set的所有元素
]]
function redisOpt.sMembers(key)
    checkParams(db, key)
    return db:sMembers(key)
end

-->>>>>>>>>>>>>>>>>>>>list相关操作>>>>>>>>>>>>>>>>>>>>
--[[
    在名称为key的list左边（头）添加一个值为value的 元素
]]
function redisOpt.lPush(key, value)
    checkParams(db, key, value)
    return db:lPush(key, value)
end

--[[
    在名称为key的list右边（尾）添加一个值为value的 元素
]]
function redisOpt.rPush(key, value)
    checkParams(db, key, value)
    return db:rPush(key, value)
end

--[[
    在名称为key的list左边（头）添加一个值为value的 元素
]]
function redisOpt.lPushx(key, value)
    checkParams(db, key, value)
    return db:lPushx(key, value)
end

--[[
    在名称为key的list右边（尾）添加一个值为value的 元素
]]
function redisOpt.rPushx(key, value)
    checkParams(db, key, value)
    return db:rPushx(key, value)
end

--[[
    输出名称为key的list左(头)起/右（尾）起的第一个元素，删除该元素
]]
function redisOpt.lPop(key)
    checkParams(db, key)
    return db:lPop(key)
end

--[[
    输出名称为key的list左(头)起/右（尾）起的第一个元素，删除该元素
]]
function redisOpt.rPop(key)
    checkParams(db, key)
    return db:rPop(key)
end

--[[
    返回名称为key的list有多少个元素
]]
-- function redisOpt.lSize(key)
--     checkParams(db, key)
--     return db:lsize(key)
-- end

--[[
    返回名称为key的list中index位置的元素
]]
function redisOpt.lIndex(key, index)
     checkParams(db, key)
     return db:lIndex(key, index)
end

--[[
    返回名称为key的list中index位置的元素
]]
function redisOpt.lSet(key, index, value)
    checkParams(db, key, value)
    db:lSet(key, index, value)
end

--[[
    返回名称为key的list中start至end之间的元素（end为 -1 ，返回所有）
]]
function redisOpt.lRange(key, startIndex, endIndex)
    checkParams(db, key)
    return db:lRange(key, startIndex, endIndex)
end

--[[
    返回key所对应的list元素个数
]]
function redisOpt.lLen(key)
    checkParams(db, key)
    return db:lLen(key)
end

--[[
    截取名称为key的list，保留start至end之间的元素
]]
function redisOpt.lTrim(key, startIndex, endIndex)
    checkParams(db, key)
    return db:lTrim(key, startIndex, endIndex)
end

--[[
    删除count个名称为key的list中值为value的元素。count为0，删除所有值为value的元素，count>0从头至尾删除count个值为value的元素，count<0从尾到头删除|count|个值为value的元素
]]
function redisOpt.lRem(key, value, count)
    checkParams(db, key, value)
    db:lrem(key, count, value)
end

--[[
    在名称为为key的list中，找到值为pivot 的value，并根据参数Redis.:BEFORE | Redis.:AFTER，来确定，newvalue 是放在 pivot 的前面，或者后面。如果key不存在，不会插入，如果 pivot不存在，return -1
]]
function redisOpt.lInsert(key, insertMode, value, newValue)
    checkParams(db, key)
    insertMode = insertMode or "after"
    db:lInsert(key, insertMode, value, newValue)
end

-->>>>>>>>>>>>>>hash操作>>>>>>>>>>>>>>>>
--[[
    向名称为h的hash中添加元素key—>value
]]
function redisOpt.hSet(h, key, value)
    checkParams(db, key, value)
    return db:hset(h, key, value)
end

--[[
    返回名称为h的hash中key对应的value
]]
function redisOpt.hGet(h, key)
    checkParams(db, key)
    return db:hget(h, key)
end

--[[
    返回名称为h的hash中元素个数
]]
function redisOpt.hLen(h)
    return db:hlen(h)
end

--[[
    删除名称为h的hash中键为key的域
]]
function redisOpt.hDel(h, key)
    checkParams(db, key)
    return db:hDel(h, key)
end

--[[
    返回名称为key的hash中所有键
]]
function redisOpt.hKeys(h)
    return db:hKeys(h)
end

--[[
    返回名称为h的hash中所有键对应的value
]]
function redisOpt.hVals(h)
   return db:hVals(h)
end

--[[
    返回名称为h的hash中所有的键（key）及其对应的value
]]
function redisOpt.hGetAll(h)
   return db:hGetAll(h)
end

--[[
    名称为h的hash中是否存在键名字为key的域
]]
function redisOpt.hExists(h, key)
   checkParams(db, key)
   return db:hExists(h, key)
end

--[[
    将名称为h的hash中key的value增加number
]]
function redisOpt.hIncrBy(h, key, number)
   checkParams(db, key)
   assert(type(number) == "number")
   return db:hIncrBy(h, key, number)
end

--[[
    向名称为key的hash中批量添加元素
]]
function redisOpt.hMset(h, vTable)
    db:hMset(h,table.unpack(vTable))
end

--[[
    返回名称为h的hash中keytable中key对应的value
]]
function redisOpt.hMGet(h, keyTable)
    return db:hMGet(h, table.unpack(keyTable))
end

--[[
    清空当前数据库
]]
function redisOpt.flushDB()
    db:flushDB()
end

--[[
    清空所有数据库
]]
function redisOpt.flushAll()
    db:flushAll()
end

--[[
    给key重命名
]]
function redisOpt.rename(key, newKey)
    checkParams(db, key)
    if redisOpt.exists(key) then
        db:renameNx(key, newKey)
    end
end

--[[
    设定一个key的活动时间（s）
]]
function redisOpt.setTimeout(key, time)
    checkParams(db, key)
    if redisOpt.exists(key) then
        db:setTimeout(key, time)
    end
end

--[[
    key存活到一个unix时间戳时间
]]
function redisOpt.expireAt(key, time)
    checkParams(db, key)
     if redisOpt.exists(key) then
        db:expireAt(key, time)
     end
end

--[[
    返回满足给定pattern的所有key
]]
function redisOpt.keys(key)
    checkParams(db, key)
    return db:keys(key)
end

function redisOpt.dbSize()
    db:dbSize()
end

--[[
    根据条件获取结果集
]]
function redisOpt.queryResult(conditions, key)
    --判断redis中是否存在key
    if redisOpt.exists(key) then
        return 1, json.decode(redisOpt.get(key))
    end
    return 2, nil
end

--[[
    把数据放在redis
]]
function redisOpt.setResult(key, result)
     redisOpt.set(key, json.encode(result))
end

--[[
    加密key
]]
function redisOpt.encryptKey(conditions)
    local c = crypt.sha1(conditions)
    return crypt.hexencode(c)
end

--关于事务的扩展 如果后期需要用到则继续封装

-->>>>>>>>>>>>>>>>>>>>>>>zset begin>>>>>>>>>>>>>>>>>>>>>>>
--[[
    添加一个到有序集合,或者如果它已经存在更新其分数
]]
function redisOpt.zAdd(key, score, member)
    checkParams(db, key)
    return db:zadd(key, score, member)
end

--[[
    添加n个到有序集合,或者如果它已经存在更新其分数
]]
function redisOpt.zNAdd(key, ...)
    checkParams(db, key)
    return db:zadd(key, ...)
end

--[[
    得到的有序集合成员的数量
]]
function redisOpt.zCard(key)
    checkParams(db, key)
    return db:zcard(key)
end

--[[
    计算一个有序集合成员与给定值范围内的分数
]]
function redisOpt.zCount(key, min, max)
    checkParams(db, key)
    return db:zcount(key, min, max)
end

--[[
    获取给定成员相关联的分数在一个有序集合
]]
function redisOpt.zScore(key, member)
    checkParams(db, key)
    return db:zscore(key, member)
end

--[[
    确定一个有序集合成员的索引，以分数排序，从高分到低分
]]
function redisOpt.zRevRank(key, member)
    checkParams(db, key)
    return db:zrevrank(key, member)
end

--[[
    确定成员的索引中有序集合
]]
function redisOpt.zRank(key, member)
    checkParams(db, key)
    return db:zrank(key, member)
end

--从有序集合中删除一个
function redisOpt.zRem(key, member)
    checkParams(db, key)
    return db:zrem(key, member)
end

--[[
    删除所有成员在给定的字典范围之间的有序集合
]]
function redisOpt.zRemRangeByLex(key, min, max)
    checkParams(db, key)
    return db:zremrangebylex(key, min, max)
end

--[[
    由索引返回一个成员范围的有序集合
]]
function redisOpt.zRange(key, start, stop, isWithscores)
    checkParams(db, key)
    if isWithscores then
        return db:zrange(key, start, stop, "WITHSCORES")
    end
    return db:zrange(key, start, stop)
end

--[[
    返回一个成员范围的有序集合，通过索引，以分数排序，从高分到低分
]]
function redisOpt.zRevRange(key, start, stop, isWithscores)
    checkParams(db, key)
    if isWithscores then
        return db:zrevrange(key, start, stop, "WITHSCORES")
    end
    return db:zrevrange(key, start, stop)
end

--[[
    在给定的索引之内删除所有成员的有序集合
]]
function redisOpt.zRemRangeByRank(key, start, stop)
    checkParams(db, key)
    return db:zremrangebyrank(key, start, stop)
end

--[[
    在给定的分数之内删除所有成员的有序集合
]]
function redisOpt.zRemRangeByScore(key, start, stop)
    checkParams(db, key)
    return db:zremrangebyscore(key, start, stop)
end

--[[
    按分数返回一个成员范围的有序集合
]]
function redisOpt.zRangeByScore(key, min, max, isWithscores)
    checkParams(db, key)
    if isWithscores then
        return db:zrangebyscore(key, min, max, "WITHSCORES")
    end
    return db:zrangebyscore(key, min, max)
end

--[[
    返回一个成员范围的有序集合，按分数，以分数排序从高分到低分
]]
function redisOpt.zRevRangeByScore(key, max, min, isWithscores)
    checkParams(db, key)
    if isWithscores then
        return db:zrevrangebyscore(key, max, min, "WITHSCORES")
    end
    return db:zrevrangebyscore(key, max, min)
end

--[[
    计算一个给定的字典范围之间的有序集合成员的数量
]]
function redisOpt.zLexCount(key, min, max)
    checkParams(db, key)
    return db:zlexcount(key, min, max)
end

--[[
    返回一个成员范围的有序集合（由字典范围）
]]
function redisOpt.zRangeByLex(key, min, max)
    checkParams(db, key)
    return db:zrangebylex(key, min, max)
end
--<<<<<<<<<<<<<<<<<<<<<<zset end<<<<<<<<<<<<<<<<<<<<<<<<

--[[
    扫描
]]
function redisOpt.scan(...)
    checkParams(db, ...)
    return db:scan(...)
end

--[[
    扫描
]]
function redisOpt.sscan(...)
    checkParams(db, ...)
    return db:sscan(...)
end

--[[
    扫描
]]
function redisOpt.hscan(...)
    checkParams(db, ...)
    return db:hscan(...)
end

--[[
    扫描
]]
function redisOpt.zscan(...)
    return db:zscan(...)
end

--[[
    发布
]]
function redisOpt.publish(channel, ...)
    checkParams(db, channel, ...)
    db:publish(channel, ...)
end

return redisOpt