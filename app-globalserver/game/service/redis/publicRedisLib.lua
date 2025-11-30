--[[
    公共redis接口
]]
local skynet = require "skynet"
local svrAddrMgr = require "svrAddrMgr"
local redisLib = require "redisLib"
local publicRedisLib = class("publicRedisLib", redisLib)

--[[
    获取redis服务地址
]]
function publicRedisLib:getAddress()
    return svrAddrMgr.getSvr(svrAddrMgr.publicRedisSvr)
end

return publicRedisLib