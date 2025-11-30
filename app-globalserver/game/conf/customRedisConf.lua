local skynet = require("skynet")
local dataCenter = require("datacenter")

local customRedisConf = {}

gCustomRedisType = {
    package = 1,
    share = 2,
    search = 3,
    activity = 4,
    conquestWar = 5,--征服战
    mailCount = 6,--邮件计数
}

gCustomRedisChannelConf = {
	[gCustomRedisType.package] = {name="DC_REDIS_PACKAGE",conf=dbconf.packageRedis},
	[gCustomRedisType.share] = {name="DC_REDIS_SHARE",conf=dbconf.shareRedis},
	[gCustomRedisType.search] = {name="DC_REDIS_SEARCH",conf=dbconf.searchRedis},
	[gCustomRedisType.activity] = {name="DC_REDIS_ACTIVITY",conf=dbconf.activityredis},
	[gCustomRedisType.conquestWar] = {name="DC_REDIS_CONQUESTWAR",conf=dbconf.conquestWarRedis},
	[gCustomRedisType.mailCount] = {name="DC_REDIS_MAIL_COUNT",conf=dbconf.mailCountRedis},
}

customRedisConf.init = function()
	for type,nameAndConf in pairs(gCustomRedisChannelConf) do
		local packageRedisAddress = skynet.newservice("redissublt",nameAndConf.name)
	    local ret = skynet.call(packageRedisAddress,"lua","connect",nameAndConf.conf)
	    gLog.i("customRedisConf.init = ",ret,packageRedisAddress)
	    if ret then
			dataCenter.set(nameAndConf.name, packageRedisAddress)
		end
	end
end

customRedisConf.getCustomRedisAddress = function(customRedisType)
	if gCustomRedisChannelConf[customRedisType] then
		return dataCenter.get(gCustomRedisChannelConf[customRedisType].name) 
	end
end

--重连
customRedisConf.reconnectRedis = function(customRedisType)
	local value = gCustomRedisChannelConf[customRedisType]
	if value then
		local redissvr = customRedisConf.getCustomRedisAddress(customRedisType)
        --断开旧连接
        skynet.send(redissvr,"lua","disconnect")
        --杀掉旧服务
        skynet.kill(redissvr)

        -- 兼容
        local packageRedisAddress = skynet.newservice("redissublt",value.name)
	    local ret = skynet.call(packageRedisAddress,"lua","connect",value.conf)
	    gLog.i("customRedisConf.reconnectRedis = ",ret,packageRedisAddress)
	    if ret then
			dataCenter.set(nameAndConf.name, packageRedisAddress)
		end

        return {ret = true,db = "game reconnectRedis "..value.name} 
	else
		return {ret = "dbtp error"}
	end	
end

return customRedisConf
