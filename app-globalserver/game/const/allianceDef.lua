--[[
    联盟相关定义
--]]

-- 联盟成员最大上限
gAliMaxMemberNum = 10

-- 联盟招募类型
gAliRecruit = {
    public = 0,     -- 公开招募
    private = 1,    -- 申请招募
}

-- 释放内存数据释放时间
gAliReleaseTime = 3600

-- 联盟计时器类型
gAliTimerType = {
    release = "release",    -- 释放
}

-- 联盟模块定义
gAliModuleDef = {
    aliInfoModule = "aliInfoCtrl",            -- 联盟主信息模块
}

-- 调试模式特殊配置
if dbconf.DEBUG then
    gAliReleaseTime = 120
end