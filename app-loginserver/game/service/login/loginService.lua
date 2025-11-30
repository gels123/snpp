require "constDef"
require "configInclude"
local skynet = require "skynet"
local socket = require "socket"
local crypt = require "crypt"
local sharedata = require "sharedata"
local cluster = require "cluster"
local svrAddrMgr = require "svrAddrMgr"

local mode = ...

if mode == "master" then
	local loginMaster = require("loginMaster"):shareInstance()
	skynet.start(function()
		-- 检查loginMaster服务是否已启动
		local loginConf = require("svrConf"):loginConfLogin(dbconf.loginnodeid)
		local svrAddress = skynet.localname(svrAddrMgr.loginMasterSvr)
		assert(not svrAddress)
		svrAddrMgr.setSvr(skynet.self(), svrAddrMgr.loginMasterSvr)

		-- 获取配置
		local instance, host, listen, port = tonumber(loginConf.instance) or 8, loginConf.host, loginConf.listen or "0.0.0.0", tonumber(loginConf.port) or 0
		assert(instance > 0 and port > 0)
	
		-- 创建子服务
		local slave, balance = {}, 1
		for i = 1, instance do
			table.insert(slave, skynet.newservice(SERVICE_NAME))
		end

		-- 监听端口, 并分发socket请求到子服务
		gLog.i(string.format("loginService listen at : %s %s %s", host, listen, port))
		local id = socket.listen(listen, port)
		socket.start(id, function(fd, addr)
			local address = slave[balance]

			balance = balance + 1
			if balance > #slave then
				balance = 1
			end

			local ok, err = pcall(loginMaster.accept, loginMaster, address, fd, addr)
			if not ok then
				skynet.error(string.format("loginService accept error: invalid client (fd = %s) error = %s", fd, err))
			end

			socket.close(fd)
		end)

		-- 分发服务间调用
		skynet.dispatch("lua", function(session, source, cmd, ...)
			xpcall(loginMaster.dispatchCmd, svrFunc.exception, loginMaster, session, source, cmd, ...)
		end)

		-- 初始化
		skynet.call(skynet.self(), "lua", "init", slave)

		-- 通知启动服务，本服务已经初始化完成
		require("serverStartLib"):finishInit(svrAddrMgr.getSvrName(svrAddrMgr.loginMasterSvr), skynet.self())
	end)
else
	local loginSlave = require("loginSlave"):shareInstance()
	skynet.start(function()
		-- 检查loginMaster服务是否已启动
		local svrAddress = skynet.localname(svrAddrMgr.loginMasterSvr)
		assert(svrAddress)

		-- 分发服务间调用
		skynet.dispatch("lua", function(session, source, cmd, ...)
			xpcall(loginSlave.dispatchCmd, svrFunc.exception, loginSlave, session, source, cmd, ...)
		end)

		-- 初始化
		skynet.call(skynet.self(), "lua", "init")
	end)
end
