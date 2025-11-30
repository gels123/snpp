--[[
	web服务
]]
require "quickframework.init"
require "svrFunc"
require "configInclude"
require "sharedataLib"
require("cluster")
local skynet = require "skynet"
local socket = require "skynet.socket"
local httpHttpd = require "http.httpd"
local httpSockethelper = require "http.sockethelper"
local httpUrl = require "http.url"
local json = require("json")
local svrConf = require "svrConf"
local webCenter = require("webCenter"):shareInstance()

local mode = ...

if mode == "agent" then
	---->>>>>>>>>>>>>>>>>>>>>> web服务代理 BEGIN >>>>>>>>>>>>>>>>>>>>>>>
	local function response(id, ...)
		local ok, err = httpHttpd.write_response(httpSockethelper.writefunc(id), ...)
		if not ok then
			-- if err == httpSockethelper.socket_error , that means socket closed.
			gLog.i(string.format("fd = %d, %s", id, err))
		end
	end

	skynet.start(function()
		local httpConf = svrConf:httpConfLogin(dbconf.loginnodeid)

		skynet.dispatch("lua", function (_, _, id)
			socket.start(id)
			-- 一般业务无需大量上行数据, 为了防止攻击, 做个 8K 限制
			local code, url, method, header, body = httpHttpd.read_request(httpSockethelper.readfunc(id), httpConf.limitbody)
			if code then
				if code ~= 200 then
					-- 如果协议解析有问题, 就回应一个错误码
					gLog.i("webService read_request error1:", code)
					response(id, code)
				else
					-- 处理web请求
					if not body or body == "" then
						url, body = httpUrl.parse(url)
						if body then
							body = httpUrl.parse_query(body)
							if body.d then
								body = body.d
							end
						end
						gLog.d("=webService query to body=", table2string(body))
					end
					if url == "/favicon.ico" then
						response(id, 200, "")
					else
						local f = webCenter[url]
						if type(f) == "function" then
							body, code = f(body)
						else
							body, code = webCenter:handleReq(body)
						end
						response(id, code or 200, type(body) == "table" and json.encode(body) or body)
					end
				end
			else
				-- 如果抛出的异常是 httpSockethelper.socket_error 表示是客户端网络断开了。
				if url == httpSockethelper.socket_error then
					gLog.i("webService read_request error2: client closed.", url)
				else
					gLog.i("webService read_request error3:", url)
				end
			end
			socket.close(id)
		end)
	end)
	----<<<<<<<<<<<<<<<<<<<<<< web服务代理 END <<<<<<<<<<<<<<<<<<<<<<<<
else
	---->>>>>>>>>>>>>>>>>>>>>> web服务 BEGIN >>>>>>>>>>>>>>>>>>>>>>>>>
	skynet.start(function()
		local agent = {}
		
		-- 启动多个代理服务用于处理HTTP请求
		local httpConf = svrConf:httpConfLogin(dbconf.loginnodeid)
		for idx = 1, httpConf.instance, 1 do
			agent[idx] = skynet.newservice(SERVICE_NAME, "agent", idx)
		end
		
		-- 监听一个 web 端口
		gLog.i("webService Listen web host=", httpConf.host, "listen=", httpConf.listen, "port=", httpConf.port)
		local id = socket.listen(httpConf.listen, httpConf.port)

		-- 接收到HTTP请求时, 把 socket id 分发到代理服务中处理
		local idx = 1
		socket.start(id, function(id, addr)
			gLog.i(string.format("%s connected, pass it to agent :%08x", addr, agent[idx]))
			skynet.send(agent[idx], "lua", id)

			idx = idx + 1
			if idx > #agent then
				idx = 1
			end
		end)
	end)
	----<<<<<<<<<<<<<<<<<<<<<< web服务 END <<<<<<<<<<<<<<<<<<<<<<<<<<
end