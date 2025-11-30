--[[
	web服务中心指令定义
]]

local webCmdDef = {
	-- PM指令定义
	CMD_PM = "1000",
		REQ_TEST = "1", -- 测试样例
		REQ_PM_ADD_FAKETIME = "2", -- 调时间
		REQ_PM_ADD_NEW_KINGDOM = "3", -- 开新服game服
		REQ_PM_ADD_NEW_GLOBAL = "4", -- 开新服global服
		REQ_PM_PING_LOGIN = "5", -- ping login服
		REQ_PM_PING_GLOBAL = "6", -- ping global服
		REQ_PM_PING_GAME = "7", -- ping game服
		REQ_PM_DELETE_SERVER = "8", -- 删除集群节点
		REQ_PM_ADD_SHARE_MAIL = "9", -- 发全服/共享邮件
}

return webCmdDef