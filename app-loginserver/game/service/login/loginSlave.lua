--[[
  登陆服务中心子服务
]]
local skynet = require "skynet.manager"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local serviceCenterBase = require("serviceCenterBase2")
local loginSlave = class("loginSlave", serviceCenterBase)

-- 初始化
function loginSlave:init()
	gLog.i("== loginSlave:init begin ==")
	-- socket最大上行数据字节数
	local loginConf = require("svrConf"):loginConfLogin(dbconf.loginnodeid)
	self.limitbody = loginConf.limitbody or 8192

	-- 账号辅助类
	self.accountHelper = require("accountHelper").new()
	self.accountHelper:init()
	-- 订阅redis玩家王国KID变更频道
	local playerDataLib = require("playerDataLib")
	playerDataLib:subscribe()
	gLog.i("== loginSlave:init end ==")
end

-- 读
function loginSlave:readline(fd)
	local v = socket.readline(fd)
	if v then
		return v
	else
		gLog.i(string.format("loginSlave:readline error: socket (fd = %d) closed", fd))
		error("socket error")
	end
end

-- 写
function loginSlave:write(fd, text)
	local v = socket.write(fd, text)
	if v then
		return v
	else
		gLog.i(string.format("loginSlave:write error: socket (fd = %d) closed", fd))
		error("socket error")
	end
end

-- 认证
function loginSlave:auth(fd, addr)
	gLog.i("loginSlave:auth enter=", fd, addr)

	socket.start(fd)

	-- set socket buffer limit(8K), if the attacker send large package, close the socket
	socket.limit(fd, self.limitbody)

	local challenge = crypt.randomkey()
	local text = string.format("%s\n", crypt.base64encode(challenge))
	gLog.d("loginSlave:auth challenge=", challenge, "text=", text)
	self:write(fd, text)

	local handshake = self:readline(fd)
	local clientKey = crypt.base64decode(handshake)
	gLog.d("loginSlave:auth handshake=", handshake, "clientKey=", clientKey, #clientKey)
	if #clientKey ~= 8 then
		skynet.error(string.format("loginSlave:auth failed1: socket (fd = %s) invalid client key", fd))
		error("invalid client key")
	end

	local serverKey = crypt.randomkey()
	local text = string.format("%s\n", crypt.base64encode(crypt.dhexchange(serverKey)))
	gLog.d("loginSlave:auth serverKey=", serverKey, "text=", text)
	self:write(fd, text)

	local secret = crypt.dhsecret(clientKey, serverKey)
	local hmac = crypt.hmac64(challenge, secret)
	local response = self:readline(fd)
	gLog.d("loginSlave:auth secret=", crypt.hexencode(secret), "hmac=", hmac, crypt.base64encode(hmac), "response=", response)
	if hmac ~= crypt.base64decode(response) then
		self:write(fd, "400 Bad Request\n")
		skynet.error(string.format("loginSlave:auth failed2: socket (fd = %d) challenge failed", fd))
		error("challenge failed")
	else
		self:write(fd, "200 challenge success\n")
	end

	local response = self:readline(fd)
	local etoken, b64encodeversion, b64encodeplateform, b64encodemodel = response:match("([^@]+)@([^@]+)@([^@]+)@(.+)")
	if not etoken then
		etoken = response
	end
	gLog.d("loginSlave:auth etoken=", etoken, b64encodeversion, b64encodeplateform, b64encodemodel)

	--客户端版本号、平台、型号
	local token = crypt.desdecode(secret, crypt.base64decode(etoken))
	local version = b64encodeversion and crypt.desdecode(secret, crypt.base64decode(b64encodeversion)) or ""
	local plateform = b64encodeplateform and crypt.desdecode(secret, crypt.base64decode(b64encodeplateform)) or ""
	local model = b64encodemodel and crypt.desdecode(secret, crypt.base64decode(b64encodemodel)) or ""
	gLog.d("loginSlave:auth token=", etoken, "version=", version, "plateform=", plateform, "model=", model)

	--第三方的账号、密码、token
	local user, password, subToken = token:match("([^@]+)@([^:]+):(.+)")
	user, password, subToken = tostring(crypt.base64decode(user)), tostring(crypt.base64decode(password)), tostring(crypt.base64decode(subToken))
	gLog.d("loginSlave:auth user,password,subToken=", user, password, subToken)

	local uInfo = self.accountHelper:getAccountInfo(user, addr, plateform)
	--gLog.dump(uInfo, "loginSlave:auth uInfo=", 10)
	if not uInfo then
		skynet.error(string.format("loginSlave:auth failed3: socket (fd = %d) account failed", fd))
		error("account failed")
	end

	gLog.i("loginSlave:auth success, fd=", fd, "user=", user)
	socket.abandon(fd)
	return secret, uInfo, version, plateform, model, user, subToken
end

-- 加载服务器配置
function loginSlave:reloadConf(nodeid)
	gLog.i("loginSlave:reloadConf", nodeid)
	self.accountHelper:updateNewUserKid()
end

function loginSlave:registerGate(nodeid)
	self.accountHelper:registerGate(nodeid)
end

function loginSlave:unregisterGate(nodeid)
	self.accountHelper:unregisterGate(nodeid)
end

return loginSlave

