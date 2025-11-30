--[[
	This file will execute before every lua service start
]]

-- 
require("quickframework.init")
-- 常量定义
require("constDef")
-- 数据库相关配置
dbconf = require("dbconf")
-- 服务地址管理
svrAddrMgr = require("svrAddrMgr")
-- 工具类
svrFunc = require("svrFunc")
-- 日志
gLog = require("newLog")

-- 设置本服务内存回收策略参数
collectgarbage("setpause", 140)
collectgarbage("setstepmul", 500)
