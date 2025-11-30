--[[
    redis分布式锁
    注： 
        1. setnx+expire非原子性操作, 如果expire无法执行, 会导致死锁, 使用原生set解决此问题 (SET key value [EX seconds] [PX milliseconds] [NX|XX])
        2. todo: 获得锁后, 超过给定秒数后, 自动释放锁, 如果业务正常耗时超过该秒数, 需要延长锁时间, 但逻辑会过于复杂, 固需要评估一个合适的值传入seconds
]]
local skynet = require "skynet"
local redisLib = require "publicRedisLib"
local redisLock = {}

local map = {}

function redisLock.trylock(key, seconds)
    local co = coroutine.running()
    if map[key] == co then
        return true
    end
    for _ = 1,seconds do
        local ret = redisLib:setexnx(key, "1", seconds)
        if ret == "OK" then
            skynet.timeout(seconds*100, function()
                if map[key] then
                    map[key] = nil
                    gLog.e("redisLock.trylock timeout key=", key, "co=", co)
                -- else
                --     gLog.i("redisLock.trylock timeout key=", key, "co=", co)
                end
            end)
            map[key] = co
            gLog.i("redisLock.trylock ok key=", key, "co=", co)
            return true
        end
        skynet.sleep(100)
        gLog.i("redisLock.trylock again key=", key, "co=", co)
    end
    return false
end

function redisLock.unlock(key)
    if map[key] then
        map[key] = nil
        local ret = redisLib:delete(key)
        gLog.i("redisLock.unlock key=", key, ret, "co=", coroutine.running())
    end
end

return redisLock