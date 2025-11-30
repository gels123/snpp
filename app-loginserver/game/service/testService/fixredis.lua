-------fixredis.lua  redis断线重连
-------
local skynet = require ("skynet")
local cluster = require ("cluster")

xpcall(function()
    gLog.i("=====fixredis begin")
    print("=====fixredis begin")

    local dbconf = require("dbconf")
    local svrAddrMgr = require("svrAddrMgr")

    --gLog.i("fixredis get gelstest", require("redisLib"):get("gelstest"))

    local address = svrAddrMgr.getSvr(svrAddrMgr.redisSvr)
    local ret = skynet.call(address, "lua", "reconnect", dbconf.redis)
    gLog.i("fixredis reconnect redis address,ret=", address, ret)

    local address = svrAddrMgr.getSvr(svrAddrMgr.publicRedisSvr)
    local ret = skynet.call(address, "lua", "reconnect", dbconf.publicRedis)
    gLog.i("fixredis reconnect publicredis address,ret=", address, ret)

    gLog.i("=====fixredis end")
    print("=====fixredis end")
end,svrFunc.exception)