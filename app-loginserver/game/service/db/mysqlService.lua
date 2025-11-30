--[[
	mysql数据库服务
	Created by Gels on 2021/8/26.
]]
require "quickframework.init"
require "constDef"
require "sharedataLib"
local skynet = require("skynet")
local cluster = require("skynet.cluster")
local svrFunc = require("svrFunc")
local mysql = require("skynet.db.mysql")

local mode, instance = ...

if mode == "master" then
	local agents = {}
	local balance = 1
	local co, inv, connected = nil, 5300, false -- coroutine and inv for auto reconnection
	local CMD = {}

	--连接mysql数据库
	function CMD.connect(conf)
		assert(conf, "mysqlService connect error: no conf!")
		--gLog.d("mysql connect conf=", table2string(conf))
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
		gLog.i("mysqlService connect ret=", ret, conf.host, conf.port)
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
		local ret = xpcall(function()
			local sql = "select 1"
			for i=1, #agents do
				skynet.call(agents[i], "lua", "execute", sql)
			end
		end, svrFunc.exception)
		-- gLog.d("mysqlService keepalive ret=", ret)
	    return ret
	end

	--重连数据库连接
	function CMD.reconnect(conf)
		assert(conf, "mysqlService connect error: no conf!")
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
		gLog.i("mysqlService reconnect ret=", ret, conf.host, conf.port)
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
				if 0 == session then -- send指令
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
    			-- gLog.d("mysqlService master dispatch cmd to agent", cmd, agent)
				if 0 == session then -- send指令
	      			skynet.send(agent, "lua", cmd, ...)
	      		else
	      			skynet.ret(skynet.pack(skynet.call(agent, "lua", cmd, ...)))
	      		end
    		end
    	end)
	end)

elseif mode == "sub" then
	local db = nil
	local CMD = {}

	-- 连接数据库
	function CMD.connect(conf)
		assert(conf, "mysqlService connect error: no conf!")
	    db = mysql.connect(conf)
	    if db then
	    	db:query("set names utf8mb4")
	    	gLog.i("mysqlService connect mysql success, dbname=", conf.database, instance)
	    	return true
	    else
	    	gLog.e("mysqlService connect mysql failed, dbname=", conf.database, instance)
	    	return false
	    end
	end

	-- 断开连接数据库
	function CMD.disconnect()
	    if db then
	      	db:disconnect()
			db = nil
	      	gLog.i("mysqlService disconnect mysql success", instance)
	      	return true
	    else
	    	gLog.e("mysqlService disconnect mysql failed", instance)
	    	return false
	    end
	end

	-- 杀死服务
	function CMD.kill()
		gLog.i("mysqlService kill", instance)
		skynet.exit()
	end

	-- 执行sql语句
	-- 报错示例1: 查询错误=>ret={badresult = true, err = "Table 'gamedata.lord' doesn't exist", errno = 1146, sqlstate = "42S02"} 
	-- 报错示例2: Mysql服务器宕机=>无ret,报错Connect to 127.0.0.1:3306 failed (Connection refused)
	function CMD.execute(sql)
		-- gLog.d("mysql execute sql=", sql)
	    local ret = nil
	    if db then
	    	local time = svrFunc.skynetTime()
			ret = db:query(sql)
			time = svrFunc.skynetTime() - time
			if time > 1 then
				gLog.i("mysql execute timeout time=, sql=", time, sql)
			end
		else
			gLog.i("[SQL ERROR] not connected, sql=", sql)
	    end
	    return ret
	end

	-- 执行sql语句
	function CMD.sendExecute(sql)
		-- gLog.d("mysql sendExecute sql=", sql)
	    if db then
	    	local time = svrFunc.skynetTime()
			local ret = db:query(sql)
			if not ret then
				gLog.i("[SQL ERROR] no ret sql=", sql)
			elseif ret.badresult or ret.err then
				gLog.i("[SQL ERROR] badresult err=", ret.err, "sql=", sql)
				-- 如果为批量提交语句，需要重新执行一次commit，防止事务挂起
				if string.find(sql, "transaction") then
					db:query("commit;")
				end
	        elseif ret.mulitresultset then
	        	-- 多条执行的sql语句错误返回值需要特殊处理
	        	for i,v in pairs(ret) do
	        		if "table" == type(v) and i~=1 and i~=#ret and (not v.affected_rows or v.affected_rows ~= 1) then
	        			ret.sql = sql
	        			gLog.dump(ret, "[SQL ERROR] mulit affected_rows error", 10)
	        			break
	        		end
	        	end
	        end
			time = svrFunc.skynetTime() - time
			if time > 1 then
				gLog.i("mysql sendExecute timeout time=, sql=", time, sql)
			end
	    end
	end

  	skynet.start(function()
  		-- 消息分发
    	skynet.dispatch("lua", function(session, source, cmd, ...)
        	local f = assert(CMD[cmd], string.format('mysql unknown operation: %s', cmd))
			if 0 == session then -- send指令
        		f(...)
        	else
        		skynet.ret(skynet.pack(f(...)))
        	end
    	end)
  	end)
end

