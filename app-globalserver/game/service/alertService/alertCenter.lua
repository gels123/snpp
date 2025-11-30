--[[
    报错信息推送服务中心
]]
local skynet = require("skynet")
local serviceCenterBase = require("serviceCenterBase2")
local alertCenter = class("alertCenter", serviceCenterBase)

function alertCenter:ctor()
end

-- 初始化本服务，不和其他服务交互
function alertCenter:init()
	gLog.i("==alertCenter:init begin==")

	self.alertMgr = require("alertMgr").new()
	self.alertMgr:init()

	gLog.i("==alertCenter:init end==")
end

function alertCenter:alert(desc, from)
	--gLog.d("alertCenter.alert", desc, from)
	if not from or from == skynet.self() then
		return
	end
	if self.alertMgr then
		self.alertMgr:push(desc, from)
	end
end

return alertCenter