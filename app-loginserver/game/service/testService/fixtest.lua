-------fixtest.lua
-------
local skynet = require ("skynet")
local cluster = require ("cluster")

xpcall(function()
    gLog.i("=====fixtest begin")
    print("=====fixtest begin")

    --local lhmac_sha256 = require("lhmac_sha256")
    --gLog.i(lhmac_sha256.hmac_sha256_bit("123456", "content"))

    local loginMaster = require("loginMaster"):shareInstance()
    gLog.dump(loginMaster, "============sdfadsf===")


    gLog.i("=====fixtest end")
    print("=====fixtest end")
end,svrFunc.exception)


