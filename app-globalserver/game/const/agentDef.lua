--[[
    微服务agent相关定义
--]]

-- 心跳超时时间
gHeartbeatTime = 45

-- 释放agent时间
gAgentFreeTime = 15*60

-- 玩家agent计时器类型
gAgentTimerType = {
    heartbeat = "heartbeat", --心跳超时
    free = "free",           --释放agent倒计时
}

-- DEBUG模式特殊配置
if dbconf.DEBUG then
    gAgentFreeTime = 2*60
end