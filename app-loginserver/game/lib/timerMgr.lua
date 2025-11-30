--[[
	计时器管理器
]]
local skynet = require "skynet"
local timerMgr = class("timerMgr")

-- 构造
function timerMgr:ctor(func, timer)
    -- 计时器关联
    self.timerMap = {}
    -- 计时器回调函数
    if func and type(func) == "function" then
    	self.func = func
	else
		self.func = function(data)
			gLog.e("timerMgr callback func ignore", data.id, data.timerType)
		end
    end
	if timer then
		self.timer = timer
	else
		-- 计时器并启动
		self.timer = require("scheduler2").new("timerMgr")
		self:startTimer()
	end
end

-- 设置过期处理函数
function timerMgr:setFunc(func)
	if func and type(func) == "function" then
    	self.func = func
    end
end

-- 设置计时器
function timerMgr:setTimer(timer)
	if timer then
		self.timer = timer
	end
end

-- 启动计时器
function timerMgr:startTimer()
	-- gLog.d("timerMgr:startTimer")
	if self.timer then
		self.timer:start()
	end
end

-- 停止计时器
function timerMgr:stopTimer()
	if self.timer then
		self.timer:pause()
	end
end

-- 更新对象倒计时
-- @id 对象ID
-- @timerType 倒计时类型
-- @endTime 倒计时
function timerMgr:updateTimer(id, timerType, endTime)
	if not id or not timerType then
		gLog.e("timerMgr:updateTimer error", id, timerType, endTime)
		return
	end
	local timerId = self.timerMap[id] and self.timerMap[id][timerType]
	if not endTime or endTime <= 0 then
		if timerId then
			gLog.i("timerMgr:updateTimer remove 1=", id, timerType, endTime, "timerId=", timerId)
			-- 删除现有计时器
			self.timer:stop(timerId)
			self.timerMap[id][timerType] = nil
			if not next(self.timerMap[id]) then
				self.timerMap[id] = nil
			end
		end
	else
		-- if timerType ~= "heartbeat" then
		-- 	gLog.i("timerMgr:updateTimer update 2=", id, timerType, endTime, "timerId=", timerId)
		-- end
		if timerId then
			-- 更新计时器回调时间
			if not self.timer:reset(timerId, endTime) then
				gLog.e("timerMgr:updateTimer error", id, timerType, endTime, "timerId=", timerId)
			end
		else
			-- 新增计时器
			timerId = self.timer:schedule(self.func, endTime, {id = id, timerType = timerType})
			if not self.timerMap[id] then
				self.timerMap[id] = {}
			end
			self.timerMap[id][timerType] = timerId
		end
	end
end

-- 删除对象(所有)倒计时
-- @id 对象Id
-- @timerType 倒计时类型
function timerMgr:removeTimer(id, timerType)
	if not id then
		gLog.e("timerMgr:updateTimer error", id, timerType)
		return
	end
	if timerType then
		local timerId = self.timerMap[id] and self.timerMap[id][timerType]
		if timerId then
			self.timer:stop(timerId)
			self.timerMap[id][timerType] = nil
			if not next(self.timerMap[id]) then
				self.timerMap[id] = nil
			end
		end
	else
		if self.timerMap[id] then
			for timerType,timerId in pairs(self.timerMap[id]) do
				self.timer:stop(timerId)
			end
			self.timerMap[id] = nil
		end
	end
end

-- 是否存在倒计时
-- @id 对象Id
-- @timerType 倒计时类型
function timerMgr:hasTimer(id, timerType)
	if id and timerType then
		if self.timerMap[id] and self.timerMap[id][timerType] then
			self.timerMap[id][timerType] = nil
			if not next(self.timerMap[id]) then
				self.timerMap[id] = nil
			end
			return true
		end
	end
	return false
end

return timerMgr
