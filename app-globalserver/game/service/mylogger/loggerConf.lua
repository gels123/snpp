local skynet = require("skynet")
local loggerConf = {}

if skynet.getenv "daemon" then
    -- debug配置
    loggerConf.debug =
    {
        level = 0, -- DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, FATAL = 4
        console = false,
        file = true,
        filename = "globald",
        path = "./log",
        maxsize = 1024000000,
    }
    -- release配置
    loggerConf.release =
    {
        level = 1, -- DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, FATAL = 4
        console = false,
        file = true,
        filename = "global",
        path = "./log",
        maxsize = 1024000000,
    }
else
    -- debug配置
    loggerConf.debug =
    {
        level = 0, -- DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, FATAL = 4
        console = true,
        file = false,
        filename = "globald",
        path = "./log",
        maxsize = 1024000000,
    }
    -- release配置
    loggerConf.release =
    {
        level = 1, -- DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, FATAL = 4
        console = true,
        file = false,
        filename = "global",
        path = "./log",
        maxsize = 1024000000,
    }
end

return loggerConf
