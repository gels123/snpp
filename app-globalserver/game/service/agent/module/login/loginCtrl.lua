--[[
	登录模块
]]
local skynet = require("skynet")
local svrFunc = require("svrFunc")
local agentCenter = require("agentCenter"):shareInstance()
local baseCtrl = require("baseCtrl")
local loginCtrl = class("loginCtrl", baseCtrl)

-- 初始化
function loginCtrl:init()
    if self.bInit then
        return
    end
    -- 设置已初始化
    self.bInit = true
    -- 是否关闭心跳
    self.close = false
end

-- 玩家checkin
function loginCtrl:checkin()
    -- 删除释放agent倒计时
    agentCenter.timerMgr:updateTimer(self.uid, gAgentTimerType.free, 0)
    -- 此时已在线, 需开启心跳, 否则数据无法释放
    local time = svrFunc.systemTime() + 2*gHeartbeatTime
    agentCenter.timerMgr:updateTimer(self.uid, gAgentTimerType.heartbeat, time)
end

-- 请求心跳
function loginCtrl:reqHeartbeat()
    if not self.close then
        local time = svrFunc.systemTime() + gHeartbeatTime
        agentCenter.timerMgr:updateTimer(self.uid, gAgentTimerType.heartbeat, time)
    end
end

-- 请求更改心跳开关
function loginCtrl:reqHeartbeatSwitch(close)
    if close then
        self.close = true
        agentCenter.timerMgr:updateTimer(self.uid, gAgentTimerType.heartbeat, 0)
    else
        self.close = false
        loginCtrl:reqHeartbeat()
    end
end

-- 玩家暂离
function loginCtrl:afk()
    gLog.i("loginCtrl:afk=", self.uid)
    agentCenter.timerMgr:updateTimer(self.uid, gAgentTimerType.heartbeat, 0)
    -- 此时需开启释放计时器, 否则数据无法释放
    local time = svrFunc.systemTime() + gAgentFreeTime
    agentCenter.timerMgr:updateTimer(self.uid, gAgentTimerType.free, time)
end

return loginCtrl
