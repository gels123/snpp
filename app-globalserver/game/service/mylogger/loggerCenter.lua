--[[
	日志服务中心
]]
local skynet = require "skynet"
local dbconf = require "dbconf"
local lfs = require "lfs"
local alertLib = require "alertLib"
local loggerCenter = class("loggerCenter")

local mathfloor = math.floor
local tableinsert = table.insert
local osdate = os.date
local tableconcat = table.concat
local osclock = os.clock
local stringsub = string.sub
local iotype = io.type
local osrename = os.rename
local stringformat = string.format
local stringfind = string.find
local ESC = string.char(27, 91)

-- 获取单例
local instance = nil
function loggerCenter.shareInstance()
    if not instance then
        instance = loggerCenter.new()
    end
    return instance
end

-- 构造
function loggerCenter:ctor()
	-- 日志等级标识
	self.logLvStr = {
		[0] = " [DEBUG]",
		[1] = " [INFO]",
		[2] = " [WARN]",
		[3] = " [ERROR]",
		[4] = " [FATAL]",
	}

	-- 颜色,参考 https://github.com/kikito/ansicolors.lua/blob/master/ansicolors.lua ; https://github.com/randrews/color
	self.color = {
		reset = ESC .. "0m",
		clear = ESC .. "2J",
		bold = ESC .. "1m",
		faint = ESC .. "2m",
		normal = ESC .. "22",
		invert = ESC .. "7m",
		underline = ESC .. "4m",
		hide = ESC .. "?25l",
		show = ESC .. "?25h",

		--foreground colors
		black = ESC .. "30" .. "m",
		red = ESC .. "31" .. "m",
		green = ESC .. "32" .. "m",
		yellow = ESC .. "33" .. "m",
	}

	-- 初始化
	self:init()
end

-- 初始化
function loggerCenter:init()
    print("==== loggerCenter:init begin ====")
	-- 日志配置
	self.conf = dbconf.DEBUG and require("loggerConf").debug or require("loggerConf").release
    -- 今日零点的UTC时间
    self.today0clock = 0
	-- 控制台
	self.console = nil
    -- 文件
	self.file = nil
    self.filesz = 0
    local curdir = lfs.currentdir()
    self.writedir = curdir
    local exist = lfs.exist(self.conf.path)
   	if exist then
   		self.writedir = self.conf.path
    end
	--
	if self.conf.file then
		self:newFiles()
	end
	--
    if self.conf.console then
		self.console = io.stdout
		-- 判断文件是否存在,存在的话,重新命名
		local debugfilename = "/.gameserver.nohup"
		local curnohupfile = tableconcat({curdir,debugfilename})
		local exist = lfs.exist(curnohupfile)
		if exist then
			local msec = stringsub(osclock(),3,6)
			local now = osdate("*t", mathfloor(skynet.time()) )
		    local curYear = now.year % 100
		    local suffix = stringformat("%d%02d%02d%s",curYear,now.month,now.day,msec)
			local newnohupfile = tableconcat({curdir,debugfilename,".",suffix})
			osrename(curnohupfile,newnohupfile)
			print("self.init rename= ",curnohupfile,newnohupfile)
		end
	end
	-- 自动清除一周前的日志
	if self.conf.file then
		local f = nil
		f = function()
			self:clearLogs()
			skynet.timeout(86400*100, f)
		end
		f()
	end
	print("==== loggerCenter:init end ====")
end

-- 生成文件对象
function loggerCenter:newFiles()
    -- 生成两份文件,一份普通文件,一份错误日志文件
	local filename = self:getNewFile(self.writedir,self.conf.filename)
    -- 打开文件
    --print("new file success1 ",filename)
    self.file = io.open(filename, "w")
    if not self.file then
    	print("open failed=",filename)
    else
    	-- 设置缓冲大小
    	self.filesz = 0
    	self.file:setvbuf("full",8192)
    end
    --print("new file success1 ",filename)
end

-- 获取最大值
function loggerCenter:getNewFile(path, filename)
	local curTime = mathfloor(skynet.time())
	local now = osdate("*t", curTime)
    local curYear = now.year % 100
    local nowfilename = stringformat("%s.%d-%d-%d.1",filename,curYear,now.month,now.day)
    local matchstr = filename .. ".(%d+)-(%d+)-(%d+).(%d+)"
	local maxIdx = 0
	for file in lfs.dir(path) do
		-- 检测年月日是否匹配
		local tmpyear,tmpmonth, tmpday,tmpIdx = string.match(file, matchstr)
	    if tmpyear and tonumber(tmpyear) == curYear and tmpmonth and tonumber(tmpmonth) == now.month and tmpday and tonumber(tmpday) == now.day and tmpIdx then
	    	tmpIdx = tonumber(tmpIdx)
	    	if maxIdx < tmpIdx then
	    		maxIdx = tmpIdx
	    	end
	    end
	end
	-- print("needRename == ",filename,", maxIdx=",maxIdx)
	maxIdx = maxIdx + 1
	local newfilename = stringformat("%s/%s.%d-%d-%d.%d",path,filename,curYear,now.month,now.day,maxIdx)
	-- print("new file max idx =",maxIdx,newfilename)
	-- 获取当前时间的时分秒
    self:takeToday0clock(curTime)

	return newfilename
end

-- 获得当前时间0点
function loggerCenter:takeToday0clock(curTime)
	local h = tonumber(osdate("%H", curTime))
    local m = tonumber(osdate("%M", curTime))
    local s = tonumber(osdate("%S", curTime))
    self.today0clock = curTime - (h * 3600 + m * 60 + s)
end

-- 将缓存输出到文件
function loggerCenter:flush()
	if self.file and iotype(self.file) == "file" then
		self.file:flush()
	end
end

-- 文件关闭
function loggerCenter:close()
	if self.file and iotype(self.file) == "file" then
		self.file:close()
	end
end

-- 系统信号
function loggerCenter:sigup()
	if self.conf.file and self.file then
		print("loggerCenter:sigup")
		-- self.file:flush()
    	-- self.file:close()
	    -- self:newFiles()
	end
end

-- 检测是否需要换新文件名字
function loggerCenter:checkNew(curTime)
	if (curTime > self.today0clock + 86400) or self.filesz > self.conf.maxsize then
		self:takeToday0clock(curTime)
		return true
	end
	return false
end

-- 自动清除一周前的日志
function loggerCenter:clearLogs()
	pcall(function()
		local shell = string.format("find %s -mtime +7 -name \"%s.*\" | xargs rm -f", self.writedir, self.conf.filename)
		--print("clearLogs=", shell)
		io.popen(shell)
	end)
end

-----------------------------指令分发begin----------------------------------------
function loggerCenter:dispatch(session, address, cmd, level, tag, file, line, ...)
	if level < self.conf.level then
		return
	end
	local time = skynet.time()
	local time2 = mathfloor(time)
	local timedata = osdate("%Y-%m-%d %H:%M:%S", time2)
	local startIdx = 5
	local tab = nil
	if level >= 2 and self.console then --输出到控制台才标注颜色
		startIdx = 6
		tab = {self.color.red, timedata, " ", time, self.logLvStr[level], tag, ... , "\n",self.color.reset}
	else
		tab = {timedata, " ", time, self.logLvStr[level], tag, ... , "\n"}
	end
	-- print("level === ",level,",tag=", tag,",file=", file,",line=", line)
	if file then
		tableinsert(tab,startIdx+1,"[")
		tableinsert(tab,startIdx+2,file)
	end
	if line then
		tableinsert(tab,startIdx+3,":")
		tableinsert(tab,startIdx+4, line)
		tableinsert(tab,startIdx+5,"] ")
	end
	local log = tableconcat(tab)
	if self.conf.file and self.file then
	    self.file:write(log)
	    if level >= 2 then --WARN后的马上刷到缓存, 否则由操作系统控制
		    self.file:flush()
		end
	    self.filesz = self.filesz + #log
	    if self:checkNew(time2) then
	    	self.file:flush()
	    	self.file:close()
	    	self:newFiles()
	    end
	end
	if self.conf.console and self.console then
		self.console:write(log)
		self.console:flush()
	end
	-- 报错信息同步到企业微信or钉钉
	if stringfind(log, "stack traceback:") then
		alertLib:alert(log, address)
	end
end

-- 记录由skynet.error转发过来的日志
function loggerCenter:skyneterr(session, address, msg)
	local time = skynet.time()
	local time2 = mathfloor(time)
	local timedata = osdate("%Y-%m-%d %H:%M:%S", time2)
	local addrstr = stringformat(":%08x ",address)
	local tab = {timedata, " ", time, " [SNERR] ", addrstr, msg, "\n"}
	local log = tableconcat(tab)
	--
	if self.conf.file and self.file then
	    self.file:write(log)
	    self.file:flush()
	    self.filesz = self.filesz + #log
	    if self:checkNew(time2) then
	    	self.file:close()
	    	self:newFiles()
	    end
	end
	--
	if self.conf.console and self.console then
		self.console:write(log)
	end
	-- 报错信息同步到企业微信or钉钉
	if stringfind(log, "stack traceback:") then
		alertLib:alert(log, address)
	end
end
-----------------------------指令分发end----------------------------------------

return loggerCenter
