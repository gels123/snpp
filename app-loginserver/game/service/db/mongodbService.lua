--[[
	mongodb数据库服务
	Created by Gels on 2025/3/04.
]]
require "quickframework.init"
require "constDef"
require "sharedataLib"
local skynet = require("skynet")
local cluster = require("skynet.cluster")
local svrFunc = require("svrFunc")
local mongo = require("skynet.db.mongo")
local bson = require("bson")

local mode, instance = ...

if mode == "master" then
	local agents = {}
	local balance = 1
	local co, inv, connected = nil, 5300, false -- coroutine and inv for auto reconnection
	local CMD = {}

	--连接mysql数据库
	function CMD.connect(conf)
		assert(conf, "mongodbService connect error: no conf!")
		--gLog.d("mongodb connect conf=", table2string(conf))
		local ret = true
	    for i=1, #agents do
      		if skynet.call(agents[i], "lua", "connect", conf) ~= true then
				ret = false
			end
    	end
		connected = ret
		if ret and not co then
			local f
			f = function()
				if not CMD.keepalive() then
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
		gLog.i("mongodbService connect ret=", ret, conf.host, conf.port)
		return ret
	end

	--断开数据库连接
	function CMD.disconnect()
		connected = false
	    for i=1, #agents do
			skynet.call(agents[i], "lua", "disconnect")
	    end
	end

	--测试数据库连接
	function CMD.keepalive()
		-- local ret = xpcall(function()
		-- 	local sql = "select 1"
		-- 	for i=1, #agents do
		-- 		local ret = skynet.call(agents[i], "lua", "execute", sql)
		-- 	end
		-- end, svrFunc.exception)
		-- gLog.d("mysqlService keepalive ret=", ret)
	    return true
	end

	--重连数据库连接
	function CMD.reconnect(conf)
		assert(conf, "mongodbService connect error: no conf!")
		connected = false
		local ret = true
		local ok = xpcall(function()
			for i=1, #agents do
				--断开旧连接
				pcall(function()
					skynet.call(agents[i], "lua", "disconnect")
				end)
				--杀死旧服务
				skynet.send(agents[i], "lua", "kill")
				--生成新服务
				agents[i] = skynet.newservice(SERVICE_NAME, "sub", i)
				--新服务连接
				if skynet.call(agents[i], "lua", "connect", conf) ~= true then
					ret = false
				end
			end
		end, svrFunc.exception)
		if not ok then
			ret = false
		end
		connected = ret
		gLog.i("mongodbService reconnect ret=", ret, conf.host, conf.port)
	    return ret
	end

	-- 是否已连接
	function CMD.isConnected()
		return connected
	end

	skynet.start(function()
		-- 启动多个代理服务
		instance = math.max(2, math.ceil((instance or 8)/2.0) * 2)
    	for i=1, instance do
      		agents[i] = skynet.newservice(SERVICE_NAME, "sub", i)
    	end
		instance = 1

    	-- 消息分发
    	skynet.dispatch("lua", function(session, source, cmd, ...)
    		local f = CMD[cmd]
    		if f then
				if 0 == session then
					f(...)
				else
					skynet.ret(skynet.pack(f(...)))
				end
    		else
      			local agent = agents[balance]
    			if balance >= #agents then
    				balance = 1
    			else 
    				balance = balance + 1
    			end
    			-- gLog.d("mongodbService master dispatch cmd to agent", cmd, agent)
				if 0 == session then -- send指令
	      			skynet.send(agent, "lua", cmd, ...)
	      		else
	      			skynet.ret(skynet.pack(skynet.call(agent, "lua", cmd, ...)))
	      		end
    		end
    	end)
	end)

elseif mode == "sub" then
	local cli, db, f = nil, nil, nil
	local CMD = {}

	-- 连接数据库
	function CMD.connect(conf)
		assert(conf, "mongodbService connect error: no conf!")
		cli = mongo.client(conf)
		if cli then
			db = cli[conf.database]
		end
	    if db then
			db:auth(conf.username, conf.password)
	    	gLog.i("mongodbService connect mongodb success, database=", conf.database, instance)
	    	return true
	    else
	    	gLog.e("mongodbService connect mongodb failed, database=", conf.database, instance)
	    	return false
	    end
	end

	-- 断开连接数据库
	function CMD.disconnect()
	    if db then
	      	db:disconnect()
	      	gLog.i("mongodbService disconnect mongodb success", instance)
	      	return true
	    else
	    	gLog.e("mongodbService disconnect mongodb failed", instance)
	    	return false
	    end
	end

	-- 杀死服务
	function CMD.kill()
		gLog.i("mongodbService kill", instance)
		skynet.exit()
	end

	function CMD.findOne(id, module, custom)
		if module then
			if not custom then
				custom = {}
			end
			custom._id = id
			gLog.dump(custom, "mongodbService findOne custom=")
			return db[module]:findOne(custom)
		end
	end

	function CMD.find(id, module, custom)
		if module then
			if not custom then
				custom = {}
			end
			custom._id = id
			local cursor = db[module]:find(custom)
			if cursor and cursor:hasNext() then
				local ret = {}
				for i=1,1000,1 do -- 最多返回1000条数据
					local v = cursor:next()
					if v then
						table.insert(ret, v)
					end
					if not cursor:hasNext() then
						break
					end
				end
				return ret
			end
		end
	end

	function CMD.findAndModify(module, custom)
		if module and custom then
			return db[module]:findAndModify(custom)
		end
	end

	function CMD.safe_insert(id, module, data, custom)
		if id and module then
			-- db[module]:ensureIndex({_id = 1}, {unique = true})
			if not custom then
				custom = {}
			end
			custom._id = id
			custom.data = data
			custom.timestamp = svrFunc.systemTime()
			local ok, err, ret = db[module]:safe_insert(custom)
			return ok, err, ret
		end
	end

	function CMD.safe_update(id, module, data, custom)
		if id and module then
			if not custom then
				custom = {}
			end
			custom.data = data
			custom.timestamp = svrFunc.systemTime()
			local ok, err, ret = db[module]:safe_update({_id = id}, {['$set'] = custom})
			if ok and ret and ret.n ~= 1 then
				custom._id = id
				ok, err, ret = db[module]:safe_insert(custom)
			end
			return ok, err, ret
		end
	end

	function CMD.delete(id, module, custom)
		if id and module then
			if not custom then
				custom = {}
			end
			custom._id = id
			db[module]:delete(custom)
		end
	end

	function CMD.drop(module)
		if module then
			return db[module]:drop()
		end
	end

	function CMD.dropIndex(module, indexName)
		if module then
			return db[module]:dropIndex(indexName)
		end
	end

	function CMD.runCommand(...)
		return db:runCommand(...)
	end

  	skynet.start(function()
  		-- 消息分发
    	skynet.dispatch("lua", function(session, source, cmd, ...)
        	f = assert(CMD[cmd], string.format('mongodb unknown operation: %s', cmd))
			if 0 == session then -- send指令
        		f(...)
        	else
        		skynet.ret(skynet.pack(f(...)))
        	end
    	end)
  	end)
end

