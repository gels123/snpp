--[[
	联盟服务中心
--]]
local skynet = require("skynet")
local mc = require("multicast")
local serviceCenterBase = require("serviceCenterBase2")
local allianceCenter = class("allianceCenter", serviceCenterBase)

-- 构造
function allianceCenter:ctor()
	self.super.ctor(self)
end

-- 初始化
function allianceCenter:init(kid, idx)
    gLog.i("==allianceCenter:init begin==", kid, idx)
	self.super.init(self, kid)

	-- 服务ID
	self.idx = idx
	-- 计时器管理
	self.timerMgr = require("timerMgr").new(handler(self, self.timerCallback), self.myTimer)
	-- 联盟信息管理
	self.allianceMgr = require("allianceMgr").new()

    gLog.i("==allianceCenter:init end==", kid, idx)
    return true
end

-- 玩家登录
function allianceCenter:login(aid, uid)
	gLog.i("allianceCenter:login begin=", aid, uid)
	if aid and aid ~= "" and uid then
		self.allianceMgr:login(aid, uid)
	end
	gLog.i("allianceCenter:login end=", aid, uid)
	return true
end

-- 玩家checkin
function allianceCenter:checkin(aid, uid)
	gLog.i("allianceCenter:checkin begin=", aid, uid)
	self.allianceMgr:checkin(aid, uid)
	gLog.i("allianceCenter:checkin end=", aid, uid)
end

-- 玩家afk
function allianceCenter:afk(aid, uid)
	gLog.i("allianceCenter:afk begin=", aid, uid)
	self.allianceMgr:afk(aid, uid)
	gLog.i("allianceCenter:afk end=", aid, uid)
end

-- 玩家彻底离线
function allianceCenter:logout(aid, uid)
	gLog.i("allianceCenter:logout begin=", aid, uid)
	self.allianceMgr:logout(aid, uid)
	gLog.i("allianceCenter:logout end=", aid, uid)
	return true
end

-- 获取联盟成员列表
function allianceCenter:getMemberUids(aid)
	if aid then
		local aliInfoCtrl = self.allianceMgr:getModule(aid, gAliModuleDef.aliInfoModule)
		return aliInfoCtrl:getMemberUids()
	end
end

-- 迁出本服
function allianceCenter:migrateOut(aid, newKid)
	gLog.i("allianceCenter:migrateOut begin=", aid, newKid)
	if aid and newKid then
		local uids = nil
		local sq = allianceCenter:getSq(aid)
		sq(function()
			local aliInfoCtrl = self.allianceMgr:getModule(aid, gAliModuleDef.aliInfoModule, true)
			if aliInfoCtrl then
				uids = aliInfoCtrl:getMemberUids()
			end
		end)
		self.allianceMgr:releaseModule(aid, newKid)
		gLog.i("allianceCenter:migrateOut end=", aid, newKid)
		return uids
	end
end

-- 给所有联盟成员推送消息
function allianceCenter:notifyMsg(aid, cmd, msg, uids)
	if aid then
		local aliInfoCtrl = self.allianceMgr:getModule(aid, gAliModuleDef.aliInfoModule)
		require("agentLib"):notifyMsgBatch(aliInfoCtrl:getMemberUids(), cmd, msg)
	elseif uids then
		require("agentLib"):notifyMsgBatch(uids, cmd, msg)
	end
end

-- call调用指定模块的指定方法
function allianceCenter:callModule(aid, module, cmd, ...)
	if aid and module and cmd then
		local ctrl = self.allianceMgr:getModule(aid, module)
		local f = ctrl[cmd]
		if type(f) == "function" then
			return f(ctrl, ...)
		else
			gLog.e("allianceCenter:callModule error", module, cmd, ...)
		end
	else
		gLog.e("allianceCenter:callModule error", aid, module, cmd, ...)
	end
end

-- send调用指定模块的指定方法
function allianceCenter:sendModule(aid, module, cmd, ...)
	if aid and module and cmd then
		local ctrl = self.allianceMgr:getModule(aid, module)
		local f = ctrl[cmd]
		if type(f) == "function" then
			f(ctrl, ...)
		else
			gLog.e("allianceCenter:sendModule error", module, cmd, ...)
		end
	else
		gLog.e("allianceCenter:sendModule error", aid, module, cmd, ...)
	end
end

-- 计时器回调
function allianceCenter:timerCallback(data)
	if dbconf.DEBUG then
		gLog.d("allianceCenter:timerCallback data=", table2string(data))
	end
	local id, timerType = data.id, data.timerType
	if self.timerMgr:hasTimer(id, timerType) then
		if timerType == gAliTimerType.release then
			self.allianceMgr:releaseModule(id)
		else
			gLog.w("allianceCenter:timerCallback ignore", id, timerType)
		end
	end
end

return allianceCenter
