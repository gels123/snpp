--[[
	服务器启动服务管理
]]
local skynet = require("skynet")
local mc = require("multicast")
local svrAddrMgr = require("svrAddrMgr")
local lextra = require("lextra")
local serverStartCenter = require("serverStartCenter"):shareInstance()
local serverStartMgr = class("serverStartMgr")

-- 构造
function serverStartMgr:ctor()
	-- 创建频道
	self.channel = mc.new()
	-- 启动服务配置
	self.mapStartedService = {}
	-- 是否所有服均已初始化好
	self.isOk = false
	-- 是否停服中
	self.stoping = false

	-- 数据中心服务
	local playerDataLib = require("playerDataLib")
	for i = 1, playerDataLib.serviceNum do
		self.mapStartedService[svrAddrMgr.getSvrName(svrAddrMgr.dataCenterSvr, dbconf.globalnodeid, i)] = false
	end
	-- 公共杂项服务
	local commonLib = require("commonLib")
	for i = 1, commonLib.serviceNum do
		self.mapStartedService[svrAddrMgr.getSvrName(svrAddrMgr.commonSvr, dbconf.globalnodeid, i)] = false
	end
	-- 微服务agent服务
	local agentLib = require("agentLib")
	for i = 1, agentLib.serviceNum do
		self.mapStartedService[svrAddrMgr.getSvrName(svrAddrMgr.agentSvrGlobal, dbconf.globalnodeid, i)] = false
	end
	-- 聊天服务
	local chatLib = require("chatLib")
	for i = 1, chatLib.serviceNum do
		self.mapStartedService[svrAddrMgr.getSvrName(svrAddrMgr.chatSvr, dbconf.globalnodeid, i)] = false
	end
	-- 联盟服务
	local allianceLib = require("allianceLib")
	for i = 1, allianceLib.serviceNum do
		self.mapStartedService[svrAddrMgr.getSvrName(svrAddrMgr.allianceSvr, dbconf.globalnodeid, i)] = false
	end
end

-- 获取频道
function serverStartMgr:getChannel()
	return self.channel and self.channel.channel
end

-- 获取是否所有服均已初始化好
function serverStartMgr:getIsOk()
	if not next(self.mapStartedService) then
		return true
	end
	return self.isOk
end

-- 完成初始化
function serverStartMgr:finishInit(svrName, address)
	gLog.i("serverStartMgr:finishInit", svrName, address, self.mapStartedService[svrName])
	if svrName and address and self.mapStartedService[svrName] ~= nil then
		self.mapStartedService[svrName] = address
		-- 判断是否所有服均已初始化好
		self:isAllServerOk()
	end
	--gLog.dump(self.mapStartedService, "serverStartMgr:finishInit mapStartedService=")
end

-- 判断是否所有服均已初始化好
function serverStartMgr:isAllServerOk()
	local isOk = true
	for k,v in pairs(self.mapStartedService) do
		if v == false then
			isOk = false
			break
		end
	end
	if isOk then
		gLog.i("serverStartMgr:isAllServerOk isOk =", isOk)
		-- 标记所有服均已初始化好
		self.isOk = isOk
		-- 频道广播
		self.channel:publish(true)
		-- 修改信号处理函数
		local svrName = string.sub(svrAddrMgr.startSvr, 2, string.len(svrAddrMgr.startSvr))
		lextra.modify_singal_handler(svrName)
		-- 全局服存活检测
		serverStartCenter:checkAliveGb()
	end
end

-- 停止所有服务
function serverStartMgr:stop()
	gLog.i("== serverStartMgr:stop begin ==")
	if self.stoping then
		gLog.i("== serverStartMgr:stop repeat ==")
		return true
	end
	-- 标记为停服中
	self.stoping = true
	-- 通知其他服停服
	for svrName, address in pairs(self.mapStartedService) do
		if address ~= skynet.self() then
			gLog.i("serverStartMgr:stop svrName, address", svrName, address)
			skynet.send(address, "lua", "stop")
		end
	end
	-- 等待其他服停服完毕后, 重新发起kill信号
	skynet.fork(function()
		while(true) do
			skynet.sleep(100)
			local ok = true
			for svrName, address in pairs(self.mapStartedService) do
				if address ~= skynet.self() then
					if not skynet.call(address, "lua", "getStoped") then
						gLog.i("serverStartMgr:stop waiting... ", svrName, address)
						ok = false
						break
					end
				end
			end
			if ok then
				break
			end
		end
		-- kill
		gLog.w("serverStartMgr:stop reset_singal_handler")
		lextra.reset_singal_handler()
	end)
	gLog.i("== serverStartMgr:stop end ==")
	return true
end

return serverStartMgr