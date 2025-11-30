--[[
	测试登录服用
]]
local skynet = require ("skynet")
local cluster = require ("cluster")

xpcall(function()	
gLog.i("=====testLogin begin")
print("=====testLogin begin")
	
	local loginMaster = require("loginMaster"):shareInstance()

	loginMaster:accept(48, 25, "127.0.0.1:55155")

gLog.i("=====testLogin end")
print("=====testLogin end")
end,svrFunc.exception)