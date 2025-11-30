-------fixsensitivewords.lua
------- inject 0000003b game/service/testService/fixsensitivewords.lua
local skynet = require ("skynet")
local cluster = require ("cluster")

xpcall(function()
	--gLog.i("=====fixsensitivewords begin")
	print("=====fixsensitivewords begin")

	-- lua版本
	local sensitiveWordsCtrl = require("sensitiveWordsCtrl").new()
	sensitiveWordsCtrl:init()

	gLog.d("===============111===", sensitiveWordsCtrl:isNameShieldWord( "ADMIINN" ))
	gLog.d("===============222===", sensitiveWordsCtrl:hasShieldedWord( "ADMIINN" ))

	-- go版本
	--while(true) do
		--
		local lsensitivewords = require("lsensitivewords").new()
		local path = require("lfs").currentdir().."/game/lib/lua-golibs/sensitivewords/dict.txt"
		lsensitivewords:sensitiveWordLoadDict(path)

		gLog.i("=============111==", lsensitivewords:sensitiveWordValidate("我嘞个草你妈的B"))
		gLog.i("=============222==", lsensitivewords:sensitiveWordReplace("00000000000000我嘞个草你妈的B00000000000000", string.byte('*')))

		skynet.sleep(1)
	--end


	--gLog.i("=====fixsensitivewords end")
	print("=====fixsensitivewords end")
end,svrFunc.exception)