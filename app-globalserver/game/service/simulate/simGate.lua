--[[
	连接游戏网关服登录
]]
local crypt = require "client.crypt"
local lfs = require("lfs")
local dbconf = require("dbconf")
local socket = require("client.socket")
local json = require "json"
local simSocket = require("simSocket")
local simGate = class("simGate", simSocket)

-- 定义事件
simGate.Gate_Success = "Gate_Success" -- 连接游戏服网关成功事件, 下面开始处理业务

-- 网关相关错误类型
simGate.Err_Gate_HandshakeSuccess = 0 --网关握手成功

-- 状态
local eGateStatus =
{
	handshake = 0,	--握手状态, 客户端发起握手包, 服务器回应
	logined = 1, 	--登录状态, 客户端发起业务包, 服务器回应
}

-- 构造
function simGate:ctor()
	simGate.super.ctor(self, "simGate")

	cc(self):addComponent("components.behavior.EventProtocol"):exportMethods()

	self.index = 0 		-- 连接版本号, 需要>=1, 每次连接都需要比之前的大, 这样可以保证握手包不会被人恶意截获复用
	self.sessionid = 0	-- 请求编号, 防止恶意截获复用
	self.session = {}

	self.status = eGateStatus.handshake

	self.last = "" --上次的socket数据缓存
end

-- 连接网关
function simGate:connectGate(host, port)
    --print("simGate:connectGate host=", host, "port=", port)
	self.index = self.index + 1
	self.status = eGateStatus.handshake
	self:connect(host, port)
end

-- @override 连接成功
function simGate:onConnected()
	--print("simSocket:onConnected", self.name, self.host, self.port, self.fd, self.connected)
	self:dispatchEvent({name = simGate.Gate_Success})
	while(true) do
		local r = self:recv()
		if r then
			self:handleMsg(r)
		elseif self.connected then
			socket.usleep(100)
		else
			print("simGate:onConnected break, sockect close!", self.name)
			break
		end
		local line = socket.readstdin()
		if line then
			self:handleCmd(line)
		end
	end
	self:onFailure()
end

-- @override 连接网关服务器失败
function simGate:onFailure()
	print("simGate:onFailure")
    self:close()
	self.last = ""
end

-- 握手
function simGate:handshake(uid)
	local text = string.format("%s:%s", uid, self.index)
	local hmac = crypt.base64encode(crypt.hmac_sha1(dbconf.secret, text))
	self.sessionid = 0
	self:request("handshake", {uid = uid, index = self.index, hmac = hmac,})
end

-- 握手回包处理
function simGate:handshakeRsp(msg)
	local sn = string.unpack(">I4", msg, 1, 4) -- 4字节sn
	local rsp = json.decode(msg:sub(5, -1)) -- json数据
	print("simGate:handshakeRsp sessionid=", sn, "rsp=", table2string(rsp))
	local cmd = sn and self.session[sn] and self.session[sn].cmd
	local code = rsp.code
	if cmd == "handshake" and code == simGate.Err_Gate_HandshakeSuccess then
		print("simGate:handshakeRsp success, code=", code, "text=", rsp.text, "\n")
		self.status = eGateStatus.logined
		-- 关闭心跳
		self:request("reqHeartbeat")
		self:request("reqHeartbeatSwitch", {close = true,})
	else
		-- 网关握手失败, 登录失败
		print("simGate:handshakeRsp fail", cmd, code, rsp.text)
		-- 如果业务拒绝断开连接防止界面一直登陆死循环
		self:onFailure()
	end
end


----------------------------------------
-- 数据解包处理和打包
----------------------------------------
-- @override 处理消息
function simGate:handleMsg(r)
	local left = r
	if self.last then
		left = self.last..r
	end
	while true do
		local msg
		msg, left = self:unpackMsg(left)
		if msg then
			self:dispatchMsg(msg)
		else
			break
		end
		if not left then
			break
		end
	end
	self.last = left
end

-- 解包消息, 数据包 = 头部2字节size+4字节sn+json数据
function simGate:unpackMsg(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s + 2 then
		return nil, text --msg, left(result已经把size去掉了)
	end
	return text:sub(3, 2 + s), text:sub(3 + s)
end

-- 处理消息
function simGate:dispatchMsg(msg)
	if self.status == eGateStatus.handshake then
		self:handshakeRsp(msg)
	else
		local sn = string.unpack(">I4", msg, 1, 4) -- 4字节sn
		local rsp = json.decode(msg:sub(5, -1)) -- json数据
		local cmd = self.session[sn] and self.session[sn].cmd or rsp.cmd
		print("simGate:dispatchMsg receive cmd=", cmd, "rsp=", table2string(rsp))
		if sn then
			self.session[sn] = nil
		end
	end
end

--eg: reqHeartbeat time=1665283633
function simGate:handleCmd(line)
	--print("simGate:handleCmd line=", line)
	local cmd
	local p = string.gsub(line, "([%w-_]+)", function (s)
		cmd = s
		return ""
	end, 1)
	local t = {}
	local f = load (p, "=" .. cmd, "t", t)
	if f then
		f()
	end
	if not next (t) then
		t = nil
	end
	if cmd then
		local ok, err = pcall(self.request, self, cmd, t)
		if not ok then
			print(string.format("invalid command (%s), error (%s)", cmd, err))
		end
	end
end

-- 发送消息
function simGate:request(cmd, data)
	print("simGate:request cmd=", cmd, "data=", table2string(data))
	self.sessionid = self.sessionid + 1
	if self.sessionid >= 2147483647 then -- 超过int32最大值, 重新开始
		self.sessionid = 1
	end
	-- 数据包 = 头部2字节+4字节sn+json数据
	local msg = {cmd = cmd, data = data,}
	self.session[self.sessionid] = msg
	local package = string.pack(">I4", self.sessionid) .. json.encode(msg)
	self:send(string.pack(">s2", package))
end

return simGate
