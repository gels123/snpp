--[[
	web服务中心
]]
local skynet = require("skynet")
local json = require("json")
local md5 = require("md5")
local svrConf = require("svrConf")
local msgCtrl = require("msgCtrl")
local svrFunc = require("svrFunc")
local svrAddrMgr = require("svrAddrMgr")
local webCmdDef = require("webCmdDef")
local webCenter = class("webCenter")

-- 服务中心单例
local instance = nil  

-- 获取单例
function webCenter.shareInstance(center)
	if not instance then
		instance = center.new()
	end
	return instance
end

-- 构造
function webCenter:ctor()
	-- 签名验证的key, 验证格式req.sign = md5(time+key)
	self.vertifyKey = "cGyZCP2QXgG#"

	-- 注册指令
  	msgCtrl.register(webCmdDef.CMD_PM, webCmdDef.REQ_TEST, handler(self, self.reqTestRsp))
  	msgCtrl.register(webCmdDef.CMD_PM, webCmdDef.REQ_PM_ADD_FAKETIME, handler(self, self.reqAddFakeTime))
  	msgCtrl.register(webCmdDef.CMD_PM, webCmdDef.REQ_PM_ADD_NEW_KINGDOM, handler(self, self.reqAddNewKingdom))
  	msgCtrl.register(webCmdDef.CMD_PM, webCmdDef.REQ_PM_ADD_NEW_GLOBAL, handler(self, self.reqAddNewGlobal))
  	msgCtrl.register(webCmdDef.CMD_PM, webCmdDef.REQ_PM_PING_LOGIN, webCenter["/health/ping/login"])
  	msgCtrl.register(webCmdDef.CMD_PM, webCmdDef.REQ_PM_PING_GLOBAL, webCenter["/health/ping/global"])
  	msgCtrl.register(webCmdDef.CMD_PM, webCmdDef.REQ_PM_PING_GAME, webCenter["/health/ping/game"])
  	msgCtrl.register(webCmdDef.CMD_PM, webCmdDef.REQ_PM_DELETE_SERVER, webCenter["/delete/server"])
	msgCtrl.register(webCmdDef.CMD_PM, webCmdDef.REQ_PM_ADD_SHARE_MAIL, handler(self, self.reqAddShareMail))
end

-- 验证请求是否合法
function webCenter:vertifySign(req)
	local sign, time = req.sign, tonumber(req.time)
	if sign and time then
		if not dbconf.DEBUG then -- 10分钟内的才是有效请求
			if time >= 32503680000 then
				time = math.floor(time/1000) -- 毫秒转秒
			end
			if svrFunc.systemTime() - time > 1800 then
				return false
			end
		end
		return md5.sumhexa(string.format("%s%s", math.floor(tonumber(req.time)), self.vertifyKey)) == sign
	end
end

-- 处理网页请求
function webCenter:handleReq(req)
	gLog.dump(req, "webCenter:handleReq req=", 10)
	if req and string.sub(req, 1, 1) ~= "{" then
		return "ok"
	else
		-- json解码
		local req = json.decode(req)
		if not req then
			return "webCenter:handleReq error: req json decode failed.", 400
		end
		-- 校验请求是否合法
		local isLegal = self:vertifySign(req)
		if not isLegal then
			return "webCenter:handleReq error: req vertify sign failed.", 401
		end
		-- 校验参数是否合法
		if type(req) ~= "table" then
			return "webCenter:handleReq error: req is not table.", 400
		end
		-- 处理请求
		local ok, rsp = msgCtrl.handle(req)
		if not ok then
			return "webCenter:handleReq error: handle failed.", 400
		end
		return rsp, 200
	end
end

--[[
	pm指令: 测试
	curl -d '{"cmd":1000,"subcmd":1,"data":{"num":12345},"sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
]]
function webCenter:reqTestRsp(req)
	gLog.dump(req, "webCenter:reqTestRsp req=", 10)
	local num = tonumber(req.data.num)
	if not num then
		return {ok = false, msg = "num is invalid.", }
	end
	if not dbconf.DEBUG then
		return {ok = false, msg = "not debug mode.", }
	end
	return {ok = true, msg = "success", ret = {num = num + 1}}
end

--[[
	PM指令: 调时间
	curl -d '{"cmd":"1000","subcmd":"2","data":{"kid":1, "time":3600},"sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://172.16.10.200:5001/
]]
function webCenter:reqAddFakeTime(req)
	if not (dbconf.BACK_DOOR) then
		return {ok = false, msg = "not backdoor mode.", }
	end
	gLog.dump(req, "webCenter:gmAddFakeTime req=", 10)
	local kid = tonumber(req.data.kid)
	local time = tonumber(req.data.time)
	if not kid or kid <= 0 or not time or time <= 0 then
		return {ok = false, msg = "kid or time is invalid.",}
	end
	local xpcallOk, ok, msg = xpcall(function()
		local address = svrConf:getSvrProxyGame(kid, svrAddrMgr.getSvrName(svrAddrMgr.startSvrGame, kid))
		return skynet.call(address, "lua", "addFakeTime", time)
	end, svrFunc.exception)
	if not xpcallOk or not ok then
		return {ok = false, msg = msg or "gameserver exception.",}
	end
	return {ok = true, msg = "success",}
end

--[[
	PM指令:开新服game服
	curl -d '{"cmd":"1000","subcmd":"3","data":{},"sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
	curl -d '{"cmd":"1000","subcmd":"3","data":{"ip":"172.16.10.200","web":"172.16.10.200"},"sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
]]
function webCenter:reqAddNewKingdom(req)
	if not (dbconf.BACK_DOOR) then
		return {ok = false, msg = "not backdoor mode.", }
	end
	gLog.dump(req, "webCenter:reqAddNewKingdom req=", 10)
	local ip = req.data and req.data.ip
	local web = req.data and req.data.web
	--
	local strSql = string.format("select max(nodeid) maxnodeid from `conf_cluster` where type = '3'")
	local ret = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", strSql)
	local maxnodeid = ret and ret[1] and ret[1].maxnodeid
	if not maxnodeid then
		return {ok = false, msg = "maxnodeid error.", }
	end
	--
	maxnodeid = maxnodeid + 1
	local strSql = string.format([[
		insert into `conf_cluster` (`nodeid`, `nodename`, `ip`, `web`, `listen`, `listennodename`, `port`, `type`) values ('%d', 'my_node_game_%d', '%s', '%s', '0.0.0.0', 'listen_my_node_game_%d', 20001, 3);
		insert into `conf_debug` (`nodeid`, `ip`, `web`, `port`) values ('%d', '%s', '%s', 23001);
		insert into `conf_gate` (`nodeid`, `web`, `address`, `proxy`, `listen`, `port`) values ('%d', '%s', '%s', '127.0.0.1', '0.0.0.0', 24001);
		insert into `conf_ipwhitelist` (`nodeid`, `ipList`, `status`) values ('%d', '127.0.0.1;', 0);
		insert into `conf_kingdom` (`kid`, `nodeid`, `status`, `startTime`, `isNew`) values ('%d', '%d', 0, '2023-01-01 00:00:00', 1);
	]],
	maxnodeid, maxnodeid, ip or "127.0.0.1", web or "127.0.0.1", maxnodeid,
	maxnodeid, ip or "127.0.0.1", web or "127.0.0.1",
	maxnodeid, web or "127.0.0.1", ip or "127.0.0.1",
	maxnodeid,
	maxnodeid, maxnodeid)
	gLog.i("webCenter:reqAddNewKingdom strSql=\n", strSql)
	local ret = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", strSql)
	if ret and not ret.err then
		return {ok = true, msg = "success", maxnodeid = maxnodeid,}
	end
	return {ok = false, msg = "insert error.", }
end

--[[
	PM指令:开新服game服
	curl -d '{"cmd":"1000","subcmd":"4","data":{},"sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
	curl -d '{"cmd":"1000","subcmd":"4","data":{"ip":"172.16.10.200","web":"172.16.10.200"},"sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
]]
function webCenter:reqAddNewGlobal(req)
	if not (dbconf.BACK_DOOR) then
		return {ok = false, msg = "not backdoor mode.", }
	end
	gLog.dump(req, "webCenter:reqAddNewGlobal req=", 10)
	local ip = req.data and req.data.ip
	local web = req.data and req.data.web
	--
	local strSql = string.format("select max(nodeid) maxnodeid from `conf_cluster` where type = '2'")
	local ret = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", strSql)
	local maxnodeid = ret and ret[1] and ret[1].maxnodeid
	if not maxnodeid then
		return {ok = false, msg = "maxnodeid error.", }
	end
	--
	maxnodeid = maxnodeid + 1
	local strSql = string.format([[
		insert into `conf_cluster` (`nodeid`, `nodename`, `ip`, `web`, `listen`, `listennodename`, `port`, `type`) values ('%d', 'my_node_global_%d', '%s', '%s', '0.0.0.0', 'listen_my_node_global_%d', 20012, 3);
		insert into `conf_debug` (`nodeid`, `ip`, `web`, `port`) values ('%d', '%s', '%s', 23012);
	]],
	maxnodeid, maxnodeid, ip or "127.0.0.1", web or "127.0.0.1", maxnodeid,
	maxnodeid, ip or "127.0.0.1", web or "127.0.0.1")
	gLog.i("webCenter:reqAddNewGlobal strSql=\n", strSql)
	local ret = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", strSql)
	if ret and not ret.err then
		return {ok = true, msg = "success", maxnodeid = maxnodeid,}
	end
	return {ok = false, msg = "insert error.", }
end

--[[
	运维指令:ping登录服
	curl -d '{"cmd":"1000","subcmd":"5","sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
	curl -X get "http://127.0.0.1:5001/health/ping/login"
]]
webCenter["/health/ping/login"] = function()
	local allOk = true
	local loginConf = require("initDBConf"):getLoginConf()
	for k,v in pairs(loginConf) do
		if v.nodeid == dbconf.loginnodeid then
			local ok = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.startSvr), "lua", "getIsOk")
			if not ok then
				allOk = false
			end
		else
			local callOk, ok = pcall(function()
				return skynet.call(svrConf:getSvrProxyLogin(v.nodeid, svrAddrMgr.startSvr), "lua", "getIsOk")
			end)
			if not (callOk and ok) then
				allOk = false
				break
			end
		end
	end
	if allOk then
		return {ok = true, msg = "alive"}, 200
	end
	return {ok = false, msg = "dead"}, 500
end

--[[
	运维指令:ping全局服
	curl -d '{"cmd":"1000","subcmd":"6","sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
	curl -X get "http://127.0.0.1:5001/health/ping/global"
]]
webCenter["/health/ping/global"] = function()
	local allOk = true
	local globalConf = require("initDBConf"):getGlobalConf()
	for k,v in pairs(globalConf) do
		local callOk, ok = pcall(function()
			return skynet.call(svrConf:getSvrProxyGlobal(v.nodeid, svrAddrMgr.startSvr), "lua", "getIsOk")
		end)
		if not (callOk and ok) then
			allOk = false
			break
		end
	end
	if allOk then
		return {ok = true, msg = "alive"}, 200
	end
	return {ok = false, msg = "dead"}, 500
end

--[[
	运维指令:ping游戏服
	curl -d '{"cmd":"1000","subcmd":"7","sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
	curl -X get "http://127.0.0.1:5001/health/ping/game"
]]
webCenter["/health/ping/game"] = function()
	local allOk = true
	local globalConf = require("initDBConf"):getGlobalConf()
	for k,v in pairs(globalConf) do
		local callOk, ok = pcall(function()
			return skynet.call(svrConf:getSvrProxyGame2(v.nodeid, svrAddrMgr.startSvr), "lua", "getIsOk")
		end)
		if not (callOk and ok) then
			allOk = false
			break
		end
	end
	if allOk then
		return {ok = true, msg = "alive"}, 200
	end
	return {ok = false, msg = "dead"}, 500
end

--[[
	gm指令: 根据ip或nodeid删除集群配置
	curl -d '{"cmd":"1000","subcmd":"8","ip":"127.0.0.1","sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
	curl -X get http://127.0.0.1:5001/delete/server?ip=127.0.0.1
	curl -X get http://127.0.0.1:5001/delete/server?nodeid=1
]]
webCenter["/delete/server"] = function(req)
	gLog.dump(req, "webCenter /delete/server=")
	local ip = req.ip
	local nodeid = tonumber(req.nodeid)
	local ret = nil
	if type(ip) == "string" then
		ip = string.trim(ip)
		if ip == "127.0.0.1" or ip == "localhost" then
			gLog.w("webCenter /delete/server fail2=", ip)
			return {ok = false, msg = "ip is 127.0.0.1 or localhost"}, 500
		end
		local sql = string.format("SELECT * FROM `conf_cluster` WHERE `ip` = '%s' OR `web`='%s'", ip, ip)
		ret = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", sql)
	elseif type(nodeid) == "number" then
		local sql = string.format("SELECT * FROM `conf_cluster` WHERE `nodeid` = '%s'", nodeid)
		ret = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", sql)
	end
	gLog.dump(ret, "webCenter /delete/server ret=")
	if not ret or ret.err or not ret[1] then
		gLog.w("webCenter /delete/server fail3=", ip)
		return {ok = false, msg = "ip or nodeid not found"}, 500
	end
	local nodes = {}
	for k,v in pairs(ret) do
		if v.type == 3 then --game
			--conf_cluster conf_debug  conf_gate conf_ipwhitelist conf_kingdom
			local sql = string.format([[
				DELETE FROM `conf_cluster` WHERE nodeid = '%s';
				DELETE FROM `conf_debug` WHERE nodeid = '%s';
				DELETE FROM `conf_gate` WHERE nodeid = '%s';
				DELETE FROM `conf_ipwhitelist` WHERE nodeid = '%s';
				DELETE FROM `conf_kingdom` WHERE nodeid = '%s';
			]], v.nodeid, v.nodeid, v.nodeid, v.nodeid, v.nodeid)
			local ret = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", sql)
			if not ret or ret.err then
				gLog.w("webCenter /delete/server fail4=", ip)
				return {ok = false, msg = "db err"}, 500
			end
			nodes[v.nodeid] = true
		elseif v.type == 2 then --global
			--conf_cluster conf_debug  conf_gate conf_ipwhitelist conf_kingdom
			local sql = string.format([[
				DELETE FROM `conf_cluster` WHERE nodeid = '%s';
				DELETE FROM `conf_debug` WHERE nodeid = '%s';
			]], v.nodeid, v.nodeid)
			local ret = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", sql)
			if not ret or ret.err then
				gLog.w("webCenter /delete/server fail4=", ip)
				return {ok = false, msg = "db err"}, 500
			end
			nodes[v.nodeid] = true
		elseif v.type == 1 then --login
			--conf_cluster conf_debug  conf_http conf_login
			local sql = string.format([[
				DELETE FROM `conf_cluster` WHERE nodeid = '%s';
				DELETE FROM `conf_debug` WHERE nodeid = '%s';
				DELETE FROM `conf_http` WHERE nodeid = '%s';
				DELETE FROM `conf_login` WHERE nodeid = '%s';
			]], v.nodeid, v.nodeid, v.nodeid, v.nodeid)
			local ret = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", sql)
			if not ret or ret.err then
				gLog.w("webCenter /delete/server fail4=", ip)
				return {ok = false, msg = "db err"}, 500
			end
			nodes[v.nodeid] = true
		end
	end
	-- 刷新集群配置
	local initDBConf = require("initDBConf")
	-- 登录服刷新配置
	local loginConf = initDBConf:getLoginConf()
	for k,v in pairs(loginConf) do
		if not nodes[v.nodeid] then
			if v.nodeid ~= dbconf.loginnodeid then
				pcall(function()
					local startSvr = svrConf:getSvrProxyLogin(v.nodeid, svrAddrMgr.startSvr)
					skynet.send(startSvr, "lua", "reloadConf", dbconf.loginnodeid)
				end)
			else
				local startSvr = svrAddrMgr.getSvr(svrAddrMgr.startSvr)
				skynet.send(startSvr, "lua", "reloadConf", dbconf.loginnodeid)
			end
		end
	end
	-- 全局服刷新配置
	local globalConf = initDBConf:getGlobalConf()
	for k,v in pairs(globalConf) do
		if not nodes[v.nodeid] then
			pcall(function()
				local startSvr = svrConf:getSvrProxyGlobal(v.nodeid, svrAddrMgr.startSvr)
				skynet.send(startSvr, "lua", "reloadConf", dbconf.loginnodeid)
			end)
		end
	end
	-- 游戏服刷新配置
	local kingdomConf = initDBConf:getKingdomConf()
	for k,v in pairs(kingdomConf) do
		if not nodes[v.nodeid] then
			pcall(function()
				local startSvr = svrConf:getSvrProxyGame2(v.nodeid, svrAddrMgr.getSvrName(svrAddrMgr.startSvrGame, v.kid))
				skynet.send(startSvr, "lua", "reloadConf", dbconf.loginnodeid)
			end)
		end
	end
	return {ok = true, msg = "success"}, 200
end

--[[
	gm指令: 发全服/共享邮件
	curl -d '{"cmd":"1000","subcmd":"9","data":{"items":[1,100]},"sign":"7bdddaedb4c4c194371cf4dcb48e034b","time":14554558413}' http://127.0.0.1:5001/
]]
function webCenter:reqAddShareMail(req)
	local items = req.data.items
	if not items or #items <= 0 or #items %2 ~= 0 then
		return {ok = false, msg = "param error.", }
	end
	for i=1,#items,1 do
		if type(tonumber(items[1])) ~= "number" then
			return {ok = false, msg = "param error.", }
		end
	end
	local cfgid = 6
	local content = {
		brief = {
			sender="System",
		},
		extra = {items = {}}
	}
	if #items >= 2 then
		local len = math.floor(#items /2)
		for i=1,len do
			local tmp = {}
			tmp.id = tonumber(items[2*i-1])
			tmp.count = tonumber(items[2*i])
			table.insert(content.extra.items,tmp)
		end
	end
	local successkids, failkids = {}, {}
	local kingdomConf = require("initDBConf"):getKingdomConf()
	for k,v in pairs(kingdomConf) do
		local ok1, ok2 = pcall(function()
			local startSvr = svrConf:getSvrProxyGame2(v.nodeid, svrAddrMgr.getSvrName(svrAddrMgr.startSvrGame, v.kid))
			return skynet.call(startSvr, "lua", "sendShareMail", cfgid, content)
		end)
		if ok1 and ok2 then
			table.insert(successkids, v.kid)
		else
			table.insert(failkids, v.kid)
		end
	end
	return {ok = true, msg = "success.", successkids=successkids, failkids=failkids}
end

return webCenter




