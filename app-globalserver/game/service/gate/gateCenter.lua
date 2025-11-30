--[[
	微服务网关服务中心
]]
local skynet = require "skynet"
local crypt = require "skynet.crypt"
local netpack = require "skynet.netpack"
local socketdriver = require "skynet.socketdriver"
local json = require "json"
local dbconf = require "dbconf"
local svrFunc = require "svrFunc"
local agentLib = require "agentLib"
local serviceCenterBase = require "serviceCenterBase2"
local gateCenter = class("gateCenter", serviceCenterBase)

-- 构造
function gateCenter:ctor()
	self.super.ctor(self)
	-- 监听的socket对象
	self.socket = nil
	-- 消息队列
	self.queue = nil

	-- 客户端连接数
	self.clientNum = 0
	-- 最大客户端连接数
	self.maxClientNum = 65535
	-- 是否无延迟
	self.nodelay = true

	-- 玩家信息
	self.uidMap = {}
	-- 玩家信息
	self.usernameMap = {}
	-- 玩家连接信息
	self.connection = {}
	self.connectionMap = {}
	self.handshake = {}
	-- 自增内部ID
	self.internalId = 0

	-- 与登录服务器连接状态
	self.bConnected = false

	-- 随机种子
	math.randomseed(tonumber(tostring(os.time()):reverse():sub(1, 6)))
end

-- 初始化
function gateCenter:init()
	gLog.i("== gateCenter:init begin ==")

	-- 开启socket监听
	self:openSocket()

	gLog.i("== gateCenter:init end ==")
end

-- 停止服务
function gateCenter:stop()
	gLog.i("====gateCenter:stop begin====")

	-- 标记停服中
	if self.stoping or self.stoped then
		return
	end
	self.stoping = true
	-- 标记已停服
	self.stoped = true
	if self.myTimer then
		self.myTimer:pause()
	end

	gLog.i("====gateCenter:stop end====")
end

-- 内存回收
function gateCenter:__gc() 
	gLog.i("gateCenter:__gc", self.queue)
	if self.queue then
		netpack.clear(self.queue)
	end
end

-- 杀死服务
function gateCenter:kill()
	gLog.i("== gateCenter:kill ==")
    skynet.exit()
end

-- 开启socket监听
function gateCenter:openSocket()
	gLog.i("gateCenter:openSocket=", self.socket)
	if not self.socket then
		local gateConf = require("svrConf"):gateConfGlobal(dbconf.globalnodeid) or {}
		local host, listen, port = gateConf.address, (gateConf.listen or "0.0.0.0"), gateConf.port
		if not (host  and listen and port) then
			gLog.w("gateCenter:openSocket ignore, host, listen, port=", host, listen, port)
			return
		end
		self.socket = socketdriver.listen(listen, port)
		gLog.i("gateCenter:openSocket socket, host, listen, port=", self.socket, host, listen, port)
		socketdriver.start(self.socket)
		return true
	else
		gLog.e("gateCenter:openSocket error: socket exist")
	end
end

-- 关闭socket监听
function gateCenter:closeSocket()
	gLog.i("gateCenter:closeSocket=", self.socket)
	if self.socket then
		socketdriver.close(self.socket)
		self.socket = nil
	end
end

-- 客户端连入
function gateCenter:open(fd, msg)
	gLog.i("gateCenter:open fd=", fd, "msg=", msg)
	-- 检查最大客户端连接数
	if self.clientNum >= self.maxClientNum then
		gLog.e("gateCenter:open error", fd, msg)
		socketdriver.close(fd)
		return false
	end
	if self.nodelay then
        socketdriver.nodelay(fd)
    end
    
    self.connection[fd] = fd
    self.clientNum = self.clientNum + 1
    self.handshake[fd] = msg --addr

    -- 开启套接字
    socketdriver.start(fd)
end

-- 客户端断开
function gateCenter:close(fd, tag, inSq)
	gLog.i("gateCenter:close", fd, tag, inSq)
	self.handshake[fd] = nil
	if self.connection[fd] then
    	self.connection[fd] = nil
    	self.clientNum = self.clientNum - 1
    	socketdriver.close(fd)
    end
	local u = self.connectionMap[fd]
	if u then
		self.connectionMap[fd] = nil
		if inSq then
			self:disconnectHandler(fd, u.username, tag)
		else
			local sq = self:getSq(u.uid)
			sq(function ()
				self:disconnectHandler(fd, u.username, tag)
			end)
			self:delSq(u.uid)
		end
	end
end

-- 客户端断开处理
function gateCenter:disconnectHandler(fd, username, tag)
	local u = self.usernameMap[username]
	if u and u.fd == fd then
		gLog.i("gateCenter:disconnectHandler enter fd=", fd, "uid=", u.uid, u.subid, tag)
		local time = skynet.time()
		--
		self.uidMap[u.uid] = nil
		self.usernameMap[username] = nil
		-- 调用agent服务, 玩家暂离
		agentLib:call(u.uid, "afk", u.uid, u.subid, 0)
		gLog.i("gateCenter:disconnectHandler end fd=", fd, "uid=", u.uid, u.subid, tag, "time=", skynet.time()-time)
	else
		gLog.i("gateCenter:disconnectHandler ignore fd=", fd, u and u.fd, "uid=", u and u.uid, u and u.subid, tag)
	end
	--gLog.dump(self, "gateCenter:disconnectHandler self=")
end

-- 客户端连入关闭fd
function gateCenter:closeclient(fd)
	local c = self.connection[fd]
	if c then
		self.connection[fd] = nil
		socketdriver.close(fd)
	end
end

-- 分发客户端消息队列
function gateCenter:dispatchQueue()
    local fd, msg, sz = netpack.pop(self.queue)
    if fd then
        -- may dispatch even the message blocked
        -- If the message never block, the queue should be empty, so only fork once and then exit.
        skynet.fork(function ()
        	self:dispatchQueue()
        end)

        self:dispatchMsg(fd, msg, sz)

        for fd, msg, sz in netpack.pop, self.queue do
            self:dispatchMsg(fd, msg, sz)
        end
    end
end

-- 分发客户端消息
function gateCenter:dispatchMsg(fd, msg, sz)
    --gLog.d("gateCenter:dispatchMsg=", fd, msg, sz)
    if self.connection[fd] then
		local addr = self.handshake[fd]
		if addr then -- atomic, not yield
			self:auth(fd, addr, msg, sz)
			self.handshake[fd] = nil
		else
			self:request(fd, msg, sz)
		end
    else
        gLog.w(string.format("gateCenter:dispatchMsg drop message from fd (%d) : %s", fd, netpack.tostring(msg, sz)))
    end
end

-- 认证 atomic, not yield
function gateCenter:auth(fd, addr, msg, sz)
	local str = netpack.tostring(msg, sz)
	gLog.d("gateCenter:auth begin, fd=", fd, addr, msg, sz, str)
	local callok, ok, result, sn = xpcall(self.doAuth, svrFunc.exception, self, fd, str, addr)
	if not callok or not ok then
		gLog.w("gateCenter:auth error", fd)
		result = result or {code = gErrDef.Err_CHAT_AUTH_ERR, text = "Bad Request",}
	else
		gLog.i("gateCenter:auth success, fd=", fd, "code=", result.code)
	end
	-- 回包
	self:sendMsg(fd, sn, result)
	-- 若认证失败, 则关闭连接
	if not callok or not ok then
		self:close(fd, "gateauth")
	end
end

-- 认证 atomic, not yield
function gateCenter:doAuth(fd, str, addr)
	local sn = string.unpack(">I4", str, 1, 4)
	local req = json.decode(str:sub(5, -1))
	gLog.dump(req, "gateCenter:doAuth sn="..sn)
	if type(req) ~= "table" or req.cmd ~= "handshake" or not req.data or not req.data.uid or not req.data.index or req.data.index <= 0 or not req.data.hmac then
		gLog.w("gateCenter:doAuth error1", fd, req.cmd)
		return false, {code = gErrDef.Err_CHAT_AUTH_ERR, text = "unauthorized",}, sn
	end
	local uid, index, hmac = req.data.uid, math.floor(req.data.index), req.data.hmac
	-- 验证
	local text = string.format("%s:%s", uid, index)
	local v = crypt.base64encode(crypt.hmac_sha1(dbconf.secret, text))
	if v ~= hmac then
		gLog.w("gateCenter:doAuth error2", fd, uid, v, "hmac=", hmac)
		return false, {code = gErrDef.Err_CHAT_AUTH_ERR, text = "401 unauthorized",}, sn
	end
	-- 登录
	if index == 1 then
		self:login(uid)
	end
	-- 是否已登录
	gLog.i("gateCenter:doAuth fd=", fd, "uid=", uid, "index=", index)
	local u = self.uidMap[uid]
	if not u then
		gLog.w("gateCenter:doAuth error3", fd, uid, index)
		return false, {code = gErrDef.Err_CHAT_AUTH_ERR, text = "not found",}, sn
	end
	local sq = self:getSq(u.uid)
	return sq(function()
		-- 连接检查版本号
		if index <= u.version then
			gLog.w("gateCenter:doAuth error4", fd, uid, index, u.version)
			return false, {code = gErrDef.Err_CHAT_AUTH_ERR, text = "forbidden",}, sn
		end
		-- 补充玩家信息
		u.fd = fd
		u.version = index
		u.addr = addr
		self.connectionMap[fd] = u
		-- 补充agent信息
		local ok, isInit = skynet.call(u.agent, "lua", "setFd", fd, uid, u.subid)
		assert(ok == true)
		gLog.i("gateCenter:doAuth success fd=", fd, "uid=", u.uid, u.subid)
		--
		return true, {code = gErrDef.Err_OK, text = "OK", subid = u.subid, isInit = isInit,}, sn
	end)
end

-- 处理消息 not atomic, may yield
function gateCenter:request(fd, msg, sz)
	--gLog.d("gateCenter:request", fd, msg, sz)
	local ok, err = pcall(self.doRequest, self, fd, msg, sz)
	if not ok then
		gLog.w("gateCenter:request error: invalid package", fd, err, msg, sz)
		if self.connection[fd] then
			self:close(fd, "gaterequest")
		end
	end
end

-- 处理消息
function gateCenter:doRequest(fd, msg, sz)
	local u = assert(self.connectionMap[fd], string.format("gateCenter:doRequest error: invalid fd=%s", fd))
	skynet.redirect(u.agent, fd, "client", 0, skynet.pack(netpack.tostring(msg, sz)))
end

-- 登陆(只允许单机登陆)
function gateCenter:login(uid)
	local sq = self:getSq(uid)
	return sq(function ()
		gLog.i("gateCenter:login enter uid=", uid)
		local time = skynet.time()
		-- 玩家已在线
		local u = self.uidMap[uid]
		if u then
			gLog.w("gateCenter:login error1=", uid, "u=", table2string(u))
			local username_, subid_, fd_ = u.username, u.subid, u.fd
			self.uidMap[uid] = nil
			self.usernameMap[username_] = nil
			-- 调用agent服务, 玩家登出
			agentLib:call(uid, "afk", uid, subid_, 1) -- 1=抢号踢出
			-- 断开连接
			if fd_ then
				self:close(fd_, "gatelogin", true)
			end
		end
		-- 玩家登陆
		self.internalId = self.internalId + 1
		local subid = self.internalId
		local username = self:usernameEncode(uid, subid)
		-- 调用聊天服务, 玩家登陆
		gLog.i("gateCenter:login call agent pool=", uid, subid, username)
		local agent = agentLib:call(uid, "login", uid, subid)
		if type(agent) ~= "number" then
			error(string.format("gateCenter:login error2: uid=%s subid=%s", uid, subid))
		end
		-- 登录成功
		local u = 
		{
			username = username,
			agent = agent,	-- 玩家agent地址
			uid = uid,
			subid = subid,
			version = 0, 	-- 连接网关版本号
			fd = 0, 		-- socket fd
			addr = nil, 	-- 地址
		}
		self.uidMap[uid] = u
		self.usernameMap[username] = u
		gLog.i("gateCenter:login success=", uid, subid, username, "time=", skynet.time()-time)
		-- you should return unique subid
		return subid
	end)
end

-- 暂离(flag:0=断网(本gate调用) 1=抢号踢出(本gate调用) 2=请求afk(agent调用) 4=链路超时(agent调用))
function gateCenter:afk(uid, subid, flag)
	local sq = self:getSq(uid)
	sq(function()
		local time = skynet.time()
		local u = self.uidMap[uid]
		gLog.i("gateCenter:afk enter uid=", uid, subid, flag)
		if u and u.fd then -- 已afk则设置u.fd=nil
			local fd = u.fd
			u.fd = nil
			local username = self:usernameEncode(uid, subid)
			if subid and u.username ~= username and subid > u.subid then --若u.subid更大, 则说明已建立新连接, 旧afk不能导致新连接afk
				gLog.w("gateCenter:afk error, u.username ~= username", uid, subid, u.subid, "fd=", fd)
				self.uidMap[uid] = nil
				self.usernameMap[username] = nil
				self.usernameMap[u.username] = nil
				-- 调用玩家代理服务, 玩家登出
				agentLib:call(uid, "afk", uid, u.subid, flag or 0)
			end
			self.uidMap[uid] = nil
			self.usernameMap[username] = nil
			-- 调用玩家代理服务, 玩家登出
			agentLib:call(uid, "afk", uid, u.subid, flag or 0)
			-- 断开连接
			if fd then
				self:close(fd, "gateafk", true)
			end
			gLog.i("gateCenter:afk success=", uid, subid, flag, "fd=", fd, "time=", skynet.time()-time)
		else
			gLog.w("gateCenter:afk ignore=", uid, subid, flag)
		end
	end)
	self:delSq(uid)
	--gLog.dump(self, "gateCenter:afk self=")
end

-- 登出(销毁agent, agent调用)
function gateCenter:logout(uid, subid, flag)
	local sq = self:getSq(uid)
	sq(function ()
		local time = skynet.time()
		local u = self.uidMap[uid]
		gLog.i("gateCenter:logout enter uid=", uid, subid, flag, u and u.fd)
		if u then
			local username = self:usernameEncode(uid, subid)
			if subid and u.username ~= username then
				gLog.e("gateCenter:logout error, u.username ~= username", uid, subid, flag, username, u.username)
				self.uidMap[uid] = nil
				self.usernameMap[username] = nil
				self.usernameMap[u.username] = nil
				-- 调用玩家代理服务, 玩家登出
				agentLib:call(uid, "logout", uid, u.subid, "gatelogout")
			end
			-- 玩家登出
			self.uidMap[uid] = nil
			self.usernameMap[username] = nil
			-- 调用玩家代理服务, 玩家登出
			agentLib:call(uid, "logout", uid, u.subid, "gatelogout")
			-- 断开连接
			if u.fd then
				self:close(u.fd, "gatelogout", true)
			end
			gLog.i("gateCenter:logout end uid=", uid, subid, flag, "time=", skynet.time()-time)
		else
			gLog.w("gateCenter:logout ignore uid=", uid, subid, flag)
		end
	end)
	self:delSq(uid)
	--gLog.dump(self, "gateCenter:logout self=")
end

-- username编码
function gateCenter:usernameEncode(uid, subid)
	return string.format("%s@%s", uid, subid)
end

-- 发送消息(json协议)
function gateCenter:sendMsg(fd, sn, result)
	local msg = json.encode(result) or ""
    -- 数据包 = 头部2字节size+4字节sn+json数据
	msg = string.pack(">I4", sn) .. msg
	socketdriver.send(fd, netpack.pack(msg))
end

-- 打印
function gateCenter:dump()
	gLog.dump(self.uidMap, "gateCenter:dump uidMap=", 10)
	gLog.dump(self.usernameMap, "gateCenter:dump usernameMap=", 10)
end

return gateCenter