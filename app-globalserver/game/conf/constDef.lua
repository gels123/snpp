--[[
	通用常量定义
]]

-- 处理超时时间
gOptTimeOut = 1

-- 服务器状态
gServerStatus = {
    NORMAL = 1,             -- 正常
    MAINTENANCE = 2,        -- 维护
}

-- 服务器白名单状态
gIpWhiteListStatus = {
    CLOSE = 0,				-- 关闭
    OPEN = 1,				-- 开启
}

-- 账号状态状态
gAccountStatus = {
    NORMAL = 0,             -- 正常
    FORBID = 1,             -- 封号
}

-- 导量方式
gImportStyle = {
    ONE = 1,			    -- 单服导量
    BALANCE = 2,			-- 多服导量
}