--[[
	redis服务
]]
require "quickframework.init"
require "constDef"
require "sharedataLib"
local skynet = require "skynet"
local cluster = require "cluster"
local svrFunc = require "svrFunc"

local mode, instance, master = ...
local find = string.find

if mode == "master" then
	local agents = {}
	local balance = 1
	local co, inv, connected = nil, 5300, false -- coroutine and inv for auto reconnection
	local channels = {} -- subscribed channels

	local CMD = {}

	-- 连接redis
	function CMD.connect(conf)
		--gLog.d("redis connect conf=", table2string(conf))
		if conf.sentinels then -- 哨兵
			local sentinel = require "sentinel"
			if master == "master" then
				conf.host, conf.port = sentinel:masterFor(conf.sentinels, conf.name)
			else
				conf.host, conf.port = sentinel:slaveFor(conf.sentinels, conf.name)
			end
		end
		local ret = true
		for i = 1, #agents do
			if skynet.call(agents[i], "lua", "connect", conf) ~= true then
				ret = false
			end
		end
		connected = ret
		if ret and not co then
			local f
			f = function()
				if not CMD.ping() then
					connected = false
					if CMD.reconnect(conf) == true then
						connected = true
						inv = 5300
					else
						inv = 700
					end
				end
				if co then
					skynet.timeout(inv, f)
				end
			end
			co = skynet.fork(f)
		end
		gLog.i("redis connect ret=", ret, conf.sentinels and ("sentinel-"..master) or nil, conf.host, conf.port)
		return ret
	end

	-- 断开redis
	function CMD.disconnect()
		connected = false
		for i = 1, #agents do
			skynet.call(agents[i], "lua", "disconnect")
		end
	end

	-- 测试redis连接
	function CMD.ping()
		local ret = true
		local ok = xpcall(function()
			for i = 1, #agents do
				local ret = skynet.call(agents[i], "lua", "ping")
				if ret ~= "PONG" then
					ret = false
					break
				end
			end
		end, svrFunc.exception)
		if not ok then
			ret = false
		end
		--gLog.d("redis ping=", ret)
		return ret
	end

	-- 重新连接redis
	function CMD.reconnect(conf)
		connected = false
		if conf.sentinels then -- 哨兵
			local sentinel = require "sentinel"
			if master == "master" then
				conf.host, conf.port = sentinel:masterFor(conf.sentinels, conf.name)
			else
				conf.host, conf.port = sentinel:slaveFor(conf.sentinels, conf.name)
			end
		end
		local ret = true
		local ok = xpcall(function()
			assert(conf.host and conf.port)
			for i = 1, #agents do
				-- 断开旧连接
				pcall(function()
					skynet.call(agents[i], "lua", "disconnect")
				end)
				-- 杀掉旧服务
				skynet.send(agents[i], "lua", "kill")
				-- 生成新服务
				agents[i] = skynet.newservice(SERVICE_NAME, "sub", i)
				-- 新服务连接
				if skynet.call(agents[i], "lua", "connect", conf) ~= true then
					ret = false
				end
			end
		end, svrFunc.exception)
		if not ok then
			ret = false
		end
		connected = ret
		gLog.i("redis reconnect ret=", ret, conf.sentinels and ("sentinel-"..master) or nil, conf.host, conf.port)
		return ret
	end

	-- 是否已连接
	function CMD.isConnected()
		return connected
	end

	-- 订阅频道
	function CMD.subscribe(conf, channel)
		if conf.sentinels then -- 哨兵
			local sentinel = require "sentinel"
			if master == "master" then
				conf.host, conf.port = sentinel:masterFor(conf.sentinels, conf.name)
			else
				conf.host, conf.port = sentinel:slaveFor(conf.sentinels, conf.name)
			end
		end
		local ret = xpcall(function()
			local redis = require "skynet.db.redis"
			local w = redis.watch(conf)
			w:subscribe(channel)
			w.conf = conf
			channels[channel] = w
		end, svrFunc.exception)
		gLog.i("redis subscribe ok=", ret, conf.sentinels and ("sentinel-"..master) or nil, conf.host, conf.port)
		return ret
	end

	-- 接收频道消息
	function CMD.message(channel)
		local w = channels[channel]
		assert(w)
		local ok, data = xpcall(function()
			return w:message()
		end, svrFunc.exception)
		if ok then
			return data
		else
			while(true) do
				skynet.sleep(700)
				if CMD.subscribe(w.conf, channel) then
					break
				end
			end
			return CMD.message(channel)
		end
	end

	-- 取消订阅频道
	function CMD.unsubscribe(channel)
		local w = channels[channel]
		if w then
			channels[channel] = nil
			w:disconnect()
		end
	end

	skynet.start(function()
		-- 启动多个代理服务
		instance = math.max(2, math.ceil((instance or 8)/2) * 2)
		for i = 1, instance do
			agents[i] = skynet.newservice(SERVICE_NAME, "sub", i)
		end

		-- 消息分发
		skynet.dispatch("lua", function(session, source, cmd, ...)
			-- gLog.d("redisService master cmd =", cmd, ...)
			local f = CMD[cmd]
			if f then
				skynet.ret(skynet.pack(f(...)))
			else
				local agent = agents[balance]
				if balance >= instance then
					balance = 1
				else
					balance = balance + 1
				end
				-- gLog.d("redisService master dispatch cmd to agent, cmd=", cmd, "agent=", agent, "session=", session)
				if 0 == session then -- send指令
					skynet.send(agent, "lua", cmd, ...)
				else
					skynet.ret(skynet.pack(skynet.call(agent, "lua", cmd, ...)))
				end
			end
		end)
	end)

else
	local redisOpt = require("redisOpt")
	skynet.start(function()
		-- 消息分发
		skynet.dispatch("lua", function(session, source, cmd, ...)
			-- gLog.d("redisService sub dispatch cmd=", cmd, ..., "session=", session)
			local time = skynet.time()
			local f = assert(redisOpt[cmd], string.format('redisService unknown redis operation: %s', cmd))
			if 0 == session then -- send指令
				f(...)
			else
				skynet.ret(skynet.pack(f(...)))
			end
			time = skynet.time() - time
			if time > 1 then
				gLog.i("redisService opt timeout time=", time, cmd, ...)
			end
		end)
	end)

end

