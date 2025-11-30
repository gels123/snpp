
local key = "test"
local key2 = "test2"
local key3 = "test3"
local set = require("set").new()
local addsuccess = set:sadd(key,22,25,26,27,28,29,30)
set:sadd(key,23)

set:sadd(key2,21)
set:sadd(key2,22)

set:sadd(key3,44)

local remsuccess = set:srem(key,25,26)
local randmember = set:srandmember(key)
print("randmember = ",randmember)
print("add/rem success = ",key,addsuccess,remsuccess)
print("ismember = ",set:ismember(key,22),set:scard(key))
local ret = set:sinter(key,key2)
dump(ret,"test dump")
for k,v in ipairs(ret) do
    print("kv == ",k,v)
end

local retmember = set:smembers(key)
dump(retmember,"member dump")
for k,v in ipairs(retmember) do
    print("member kv == ",k,v)
end

set = nil
collectgarbage("collect")
skynet.sleep(10000000000)