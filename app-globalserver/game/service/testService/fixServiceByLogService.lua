--[[
	用法：
		log fixServiceByLogService 服务名 注入脚本全路径
		如：
		log fixServiceByLogService rankService /opt/rok/gameserver_2_1/game/service/testService/xxx.lua
		在MOA自动化运营后台以log文件方式注入，只需在参数框填入
		rankService,/opt/rok/gameserver_2_1/game/service/testService/xxx.lua
--]]
require "quickframework.init"
require "configInclude"
require "svrFunc"
require "sharedataLib"
local skynet = require "skynet"
local core = require "skynet.core"

local logServiceName, logFileFullPath = ...
logServiceName, logFileFullPath = tostring(logServiceName), tostring(logFileFullPath)

gLog.i("fix fixServiceByLogService enter=", logServiceName, logFileFullPath)

if type(logFileFullPath) ~= "string" or type(logServiceName) ~= "string" then
	gLog.i("fix fixServiceByLogService error", logServiceName, logFileFullPath)
	return
end

function split(szFullString, szSeparator)  
    local nFindStartIndex = 1  
    local nSplitIndex = 1  
    local nSplitArray = {}  
    while true do  
       local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)  
       if not nFindLastIndex then  
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))  
        break  
       end  
       nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)  
       nFindStartIndex = nFindLastIndex + string.len(szSeparator)  
       nSplitIndex = nSplitIndex + 1  
    end  
    return nSplitArray  
end  

local function adjust_address(address)
	local prefix = address:sub(1,1)
	if prefix == '.' then
		return assert(skynet.localname(address), "Not a valid name")
	elseif prefix ~= ':' then
		address = assert(tonumber("0x" .. address), "Need an address") | (skynet.harbor(skynet.self()) << 24)
	end
	return address
end

local function inject(address, filename)
	gLog.i("fix fixServiceByLogService inject1=", address, filename)
	address = adjust_address(address)
	gLog.i("fix fixServiceByLogService inject2=", address, filename)

	local f = io.open(filename, "rb")
	if not f then
		gLog.i("fix fixServiceByLogService inject error=", address, filename)
		return false, "Can't open " .. filename
	end
	local source = f:read("*a")
	f:close()

	gLog.i("fix fixServiceByLogService inject3=", address, filename)
	local ok, output = skynet.call(address, "debug", "RUN", source, filename)
	if ok == false then
		gLog.e(output)
	end
	return ok, output
end

local function startLogService()
	gLog.i("fix fixServiceByLogService startLogService begin")

	local arrServiceId = {}
	local retList = skynet.call(".launcher", "lua", "LIST")
	for strAddress, strSvrName in pairs(retList) do
		local address = string.format("%d", "0x"..string.sub(strAddress, 2))
		local arrName = split(strSvrName, " ")
		local svrName = arrName[2]
		if string.match(svrName, logServiceName) then
			gLog.i("fix fixServiceByLogService startLogService svrName=", svrName, address)
			table.insert(arrServiceId, address)
		end
	end
	gLog.i("fix fixServiceByLogService startLogService arrServiceId=", table2string(arrServiceId))
	if next(arrServiceId) then
		for _, address in pairs(arrServiceId) do
			pcall(function()
				local ret, result = inject(address, logFileFullPath)
				gLog.i("fix fixServiceByLogService startLogService address= ",address, ret, result, logFileFullPath)
			end)
		end
	else
		gLog.i("fix fixServiceByLogService startLogService arrServiceId is 0")
	end
	gLog.i("fix fixServiceByLogService startLogService end")

	-- 服务退出
	skynet.exit()
end

-- 启动一个新的服务
skynet.start(function ()
	skynet.fork(function ()
    	local ok, ret = xpcall(startLogService, svrFunc.exception)
    	if ok then
    		gLog.i("fix fixServiceByLogService end: sccess=", logServiceName, ok, ret)
		else
			gLog.i("fix fixServiceByLogService end: failed=", logServiceName, ok, ret)
		end
    end)
end)

