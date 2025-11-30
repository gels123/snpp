--[[
	联盟信息管理
--]]
local skynet = require("skynet")
local svrFunc = require("svrFunc")
local multiProc = require("multiProc")
local allianceCenter = require("allianceCenter"):shareInstance()
local allianceMgr = class("allianceMgr")

-- 构造
function allianceMgr:ctor()
	self.modules = {}		-- 模块
	self.alive = {}			-- 保持内存不释放
end

-- 获取模块
function allianceMgr:getModule(aid, module)
	assert(aid and module)
	if not self.modules[aid] then
		self:initModule(aid)
	end
	assert(self.modules[aid][module], "allianceMgr:getModule error: not exist!")
	allianceCenter.timerMgr:updateTimer(aid, gAliTimerType.release, svrFunc.systemTime() + gAliReleaseTime)
	return self.modules[aid][module]
end

-- init模块
function allianceMgr:initModule(aid)
	gLog.i("==allianceMgr:initModule begin==", aid)
	local sq = allianceCenter:getSq(aid)
	sq(function()
		-- 再次检查是否init模块
		if self.modules[aid] then
			return
		end
		--
		local modules = {}
		-- 并行执行查库任务(mysql会是性能热点), 需优先执行的模块放上面
		local mp = multiProc.new()
		-- 联盟主信息
		mp:fork(function()
			local module = gAliModuleDef.aliInfoModule
			local aliInfoCtrl = require(module).new(aid)
			aliInfoCtrl:init()
			modules[module] = aliInfoCtrl
		end)
		-- 等待所有任务执行结束
		mp:wait()
		-- 赋值
		self.modules[aid] = modules
		-- 更新释放计时器
		allianceCenter.timerMgr:updateTimer(aid, gAliTimerType.release, svrFunc.systemTime() + gAliReleaseTime)
	end)
	gLog.i("==allianceMgr:initModule end==", aid)
end

-- 卸载模块
-- @newKid 迁出的新王国
function allianceMgr:releaseModule(aid, newKid)
	local sq = allianceCenter:getSq(aid)
	sq(function()
		gLog.i("==allianceMgr:releaseModule begin==", aid, newKid)
		if self.modules[aid] then
			-- 取消各模块计时器

			-- 卸载模块
			self.modules[aid] = nil
		end
		--
		self.alive[aid] = nil
		-- 通知数据中心联盟彻底离线
		--playerDataLib:logout(allianceCenter.kid, nil, aid, newKid)
		gLog.i("==allianceMgr:releaseModule end==", aid, newKid)
	end)
	allianceCenter:delSq(aid)
	--gLog.dump(self, "allianceMgr:releaseModule self=")
end

-- 登录
function allianceMgr:login(aid, uid)
	if aid and uid then
		-- 联盟首个成员登录, 拉起联盟数据
		local aliInfoCtrl = self:getModule(aid, gAliModuleDef.aliInfoModule)
		-- 保持内存不释放
		if not self.alive[aid] then
			self.alive[aid] = {}
		end
		self.alive[aid][uid] = 0  -- 0=登录login, 1=在线checkin
	end
end

-- checkin
function allianceMgr:checkin(aid, uid)
	if aid and uid then
		-- 保持内存不释放
		if not self.alive[aid] then
			self.alive[aid] = {}
		end
		self.alive[aid][uid] = 1  -- 0=登录login, 1=在线checkin
	end
end

-- afk
function allianceMgr:afk(aid, uid)
	-- 玩家afk
	if aid and uid then
		-- 保持内存不释放
		if self.alive[aid] then
			self.alive[aid][uid] = 0  -- 0=登录login, 1=在线checkin
		end
	end
end

-- 彻底离线
function allianceMgr:logout(aid, uid)
	if aid and self.modules[aid] then
		if self.alive[aid] then
			self.alive[aid][uid] = nil
			-- 若所有联盟成员都彻底离线, 则卸载内存
			if not next(self.alive[aid]) then
				self.alive[aid] = nil
				self:releaseModule(aid)
			end
		end
	end
end

return allianceMgr