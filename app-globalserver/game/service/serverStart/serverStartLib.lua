--[[
	服务器启动服务接口
]]
local skynet = require ("skynet")
local serverStartLib = class("serverStartLib")

-- 获取服务地址
function serverStartLib:getAddress()
    return svrAddrMgr.getSvr(svrAddrMgr.startSvr)
end

-- call调用
function serverStartLib:call(...)
    return skynet.call(self:getAddress(), "lua", ...)
end

-- send调用
function serverStartLib:send(...)
    skynet.send(self:getAddress(), "lua", ...)
end

-- 获取频道
function serverStartLib:getChannel()
    return self:call("getChannel")
end

-- 获取是否所有服均已初始化好
function serverStartLib:getIsOk()
    return self:call("getIsOk")
end

-- 完成初始化
function serverStartLib:finishInit(svrName, address)
    self:send("finishInit", svrName, address)
end

-- 停止所有服务
function serverStartLib:stop()
    self:send("stop")
end

-- 业务ID映射全局服节点
function serverStartLib:hashNodeidGb(id)
    return self:call("hashNodeidGb", id)
end

return serverStartLib
