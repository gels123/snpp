-------fixtest.lua
-------
local skynet = require ("skynet")
local cluster = require ("cluster")

xpcall(function()
	gLog.i("=====fixtest begin")
	print("=====fixtest begin")
	--
	--while(true) do
	--	--
	--	local lsensitivewords = require("lsensitivewords").new()
	--	local path = require("lfs").currentdir().."/game/lib/lua-golibs/sensitivewords/dict.txt"
	--	lsensitivewords:sensitiveWordLoadDict(path)
	--
	--	gLog.i("=============111==", lsensitivewords:sensitiveWordValidate("我嘞个草你妈的B"))
	--	gLog.i("=============222==", lsensitivewords:sensitiveWordReplace("00000000000000我嘞个草你妈的B00000000000000", string.byte('*')))
	--
	--	skynet.sleep(1)
	--end

	--a = string.pack(">I4",8991)
	--b = string.pack(">s2",a.."{xxxdfadfxxx}")
	--c = string.unpack(">s2", b)
	--
	--print(c)
	--print(string.sub(c, 1, 4))
	--print(string.sub(c, 5, -1))
	--print(string.unpack(">I4", c, 1, 4))

	local allianceLib = require("allianceLib")
	--gLog.d("===========sdfadsfadf===", playerDataLib:getKidOfUid(10002, 6744))

	allianceLib:login(200001, 6754)

	gLog.i("=====fixtest end")
	print("=====fixtest end")
end,svrFunc.exception)