--[[
	模拟客户端套接字封装
]]
local socket = require("client.socket")
local simSocket = class("simSocket")

-- 构造
function simSocket:ctor(name, host, port)
	self.name = name or ""  -- 名字
    self.host = host 		-- ip
    self.port = port 		-- 端口
    self.fd = nil	 		-- fd
    self.connected = false	-- 已连接
end

-- 连接服务器
function simSocket:connect(host, port)
	self.host = host or self.host
	self.port = port or self.port
    assert(self.host or self.port, "simSocket:connect error: host or port invalid.")
    --print("simSocket:connect name=", self.name, "host=", self.host, "port=", self.port)
    -- 已有连接, 先关闭
	if self.fd then
		self:close()
	end
	local fd = socket.connect(self.host, self.port)
	if fd then
		-- 连接成功
		self.fd = fd
		self.connected = true
		--print("simSocket:connect success", self.name, self.host, self.port, self.fd, self.connected)
		self:onConnected()
	else
		self:onFailure()
	end
end

-- 发送数据
function simSocket:send(package)
	--print("simSocket:send", self.name, self.fd, package)
	assert(self.connected, self.name .. " is not connected.")
	socket.send(self.fd, package)
end

-- 关闭/断开连接
function simSocket:close()
	--print("simSocket:close", self.name, self.fd)
	if self.fd then
		socket.close(self.fd)
		self.fd = nil
		self.connected = false
	end
end

-- @override 连接失败
function simSocket:onFailure()
	print("simSocket:onFailure", self.name, self.host, self.port)
end

-- @override 连接成功
function simSocket:onConnected()
	--print("simSocket:onConnected", self.name, self.host, self.port)
	while(true) do
		local r = self:recv()
		if r then
			self:handleMsg(r)
		elseif self.connected then
			socket.usleep(100)
		else
			if self.connected then
				print("simSocket:onConnected break, sockect close!", self.name)
			end
			break
		end
	end
end

-- 接收消息
function simSocket:recv()
	--print("simSocket:recv", self.name)
	while true do
		if not self.connected then
			break
		end
		local r = socket.recv(self.fd)
		-- print("simSocket:recv recv=", r)
		if r == "" then -- Server closed
			self:close()
			break
		end
		if r == nil then
			break
		end
		return r
	end
end

-- @override 处理消息
function simSocket:handleMsg(r)
	print("simSocket:handleMsg ignore r=", r)
end

return simSocket
