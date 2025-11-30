--[[
    [已废弃]玩家数据中心写db异常处理文件
--]]
local skynet = require("skynet")
local json = require("json")
local lfs = require("lfs")
local playerDataCenter = require("playerDataCenter"):shareInstance()
local playerDataFileWriter = class("playerDataFileWriter")

-- 构造
function playerDataFileWriter:ctor()
    -- 文件路径
    self.fileDir = lfs.currentdir()
    -- 文件名
    self.fileName = string.format("%s%s", "mysql_error", playerDataCenter.idx)
    -- 最大文件大小
    self.maxFileSize = 1024000000

    -- 写入文件长度
    self.infoLen = 0
    -- 写入文件
    self.infoFile = nil
    -- 今日零点的UTC时间戳
    self.today0clock = 0
end

-- 初始化
function playerDataFileWriter:init(fileDir, fileName)
    gLog.i("==playerDataFileWriter:init begin==", playerDataCenter.idx)
    -- 文件路径
    if fileDir then
        self.fileDir = fileDir
    end
    -- 文件名
    if fileName then
        self.fileName = string.format("%s%s", fileName, playerDataCenter.idx)
    end
    gLog.i("==playerDataFileWriter:init end==", playerDataCenter.idx)
end

-- 生成文件对象
function playerDataFileWriter:newFiles()
    if not lfs.exist(self.fileDir) then
        self.fileDir = lfs.currentdir()
    end
    gLog.i("playerDataFileWriter:newFiles fileDir=", self.fileDir, "fileName=", self.fileName)
    local infoFilename = self:getNewFile(self.fileDir, self.fileName)
    gLog.i("playerDataFileWriter:newFiles infoFilename=", infoFilename)
    -- 打开文件
    self.infoFile = io.open(infoFilename, "w")
    if not self.infoFile then
        gLog.e("playerDataFileWriter:newFiles error: open file failed.", infoFilename)
    else
        -- 设置缓冲大小
        self.infoLen = 0
        self.infoFile:setvbuf("full", 8192)
        gLog.i("playerDataFileWriter:newFiles open file success.", infoFilename)
    end
end

-- 获取文件名
function playerDataFileWriter:getNewFile(path, fileName)
    local curTime = math.floor(skynet.time())
    local now = os.date("*t", curTime)
    local curYear = now.year % 100
    local matchstr = fileName .. ".(%d+)-(%d+)-(%d+).(%d+)"
    local maxIdx = 0
    for file in lfs.dir(path) do
        -- 检测年月日是否匹配
        local tmpyear, tmpmonth, tmpday, tmpIdx = string.match(file, matchstr)
        if tmpyear and tonumber(tmpyear) == curYear and tmpmonth and tonumber(tmpmonth) == now.month and tmpday and tonumber(tmpday) == now.day and tmpIdx then
            tmpIdx = tonumber(tmpIdx)
            if maxIdx < tmpIdx then
                maxIdx = tmpIdx
            end
        end
    end
    -- print("needRename == ",fileName,", maxIdx=",maxIdx)
    maxIdx = maxIdx + 1
    local newfilename = string.format("%s/%s.%d-%d-%d.%d", path, fileName, curYear, now.month, now.day, maxIdx)
    -- print("new file max idx =",maxIdx,newfilename)
    -- 获取当前时间的时分秒
    self:takeToday0clock(curTime)

    return newfilename
end

-- 获得当前时间0点
function playerDataFileWriter:takeToday0clock(curTime)
    local h = tonumber(os.date("%H", curTime))
    local m = tonumber(os.date("%M", curTime))
    local s = tonumber(os.date("%S", curTime))
    self.today0clock = curTime - (h * 3600 + m * 60 + s)
    -- print("playerDataFileWriter:takeToday0clock =", self.today0clock)
end

-- 将缓存输出到文件
function playerDataFileWriter:flush()
    if self.infoFile and io.type(self.infoFile) == "file" then
        self.infoFile:flush()
    end
end

-- 文件关闭
function playerDataFileWriter:close()
    if self.infoFile and io.type(self.infoFile) == "file" then
        self.infoFile:close()
        self.infoLen = 0
        self.infoFile = nil
    end
end

-- 检测是否需要换新文件名字
function playerDataFileWriter:checkNew(curTime)
    curTime = math.floor(curTime)
    if (curTime > self.today0clock + 86400) or self.infoLen > self.maxFileSize then
        self:takeToday0clock(curTime)
        return true
    end
    return false
end

-- 写文件
function playerDataFileWriter:writeFile(str)
    if dbconf.DEBUG then
        gLog.d("playerDataFileWriter:writeFile str=", str)
    end
    if type(str) == "string" and #str > 0 then
        -- 生成文件对象
        if not self.infoFile then
            self:newFiles()
        end
        local curTime = skynet.time()
        if self.infoFile then
            self.infoFile:write(curTime.."#"..str.."#\n")
            self.infoFile:flush()
            self.infoLen = self.infoLen + #str
            if self:checkNew(curTime) then
                self.infoFile:flush()
                self.infoFile:close()
                self:newFiles()
            end
        end
    end
end

-- 读取mysql异常处理文件并落库
function playerDataFileWriter:loadFile1()
    gLog.i("playerDataFileWriter:loadFile1 begin", playerDataCenter.idx)
    -- 校验mysql是否异常
    local ret = playerDataCenter:executeSql("select 1")
    -- gLog.dump(ret, "playerDataFileWriter:loadFile1 ret=", 10)
    if not ret or ret.err then
        gLog.e("playerDataFileWriter:loadFile1 error: mysql exception!")
        return
    end
    -- 遍历读取文件, 并执行文件sql
    local fileArray = {}
    if not lfs.exist(self.fileDir) then
        self.fileDir = lfs.currentdir()
    end
    gLog.i("playerDataFileWriter:loadFile1 fileDir=", self.fileDir, "fileName=", self.fileName)
    for file in lfs.dir(self.fileDir) do
        if string.find(file, self.fileName) then
            table.insert(fileArray, file)
        end
    end
    if #fileArray <= 0 then
        return
    end
    local matchstr = self.fileName .. ".(%d+)-(%d+)-(%d+).(%d+)"
    table.sort(fileArray, function (a, b) -- 文件按时间由早到晚排序
        local y1, m1, d1, i1 = string.match(a, matchstr)
        local y2, m2, d2, i2 = string.match(b, matchstr)
        y1, m1, d1, i1, y2, m2, d2, i2 = tonumber(y1), tonumber(m1), tonumber(d1), tonumber(i1), tonumber(y2), tonumber(m2), tonumber(d2), tonumber(i2)
        -- gLog.d("playerDataFileWriter:loadFile2 sort a=", y1, m1, d1, i1, "b=", y2, m2, d2, i2)
        if y1 and m1 and d1 and i1 and y2 and m2 and d2 and i2 then
            if y1 == y2 then
                if m1 == m2 then
                    if d1 == d2 then
                        return i1 < i2
                    else
                        return d1 < d2
                    end
                else
                    return m1 < m2
                end
            else
                return y1 < y2
            end
        end
    end)
    gLog.i("playerDataFileWriter:loadFile1 #fileArray", #fileArray, table2string(fileArray))
    local successArray = {}
    for _,file in ipairs(fileArray) do
        local filename = string.format("%s/%s", self.fileDir, file)
        for line in io.lines(filename) do
            local tmp = svrFunc.split(line, "#")
            gLog.i("playerDataFileWriter:loadFile1 do=", file, tmp[1], tmp[2])
            if tmp[1] and tmp[2] then
                skynet.fork(function ()
                    playerDataCenter:executeSqlSafe(tmp[2])
                end)
            end
        end
        table.insert(successArray, file)
    end
    -- 删除文件
    for _,file in pairs(successArray) do
        xpcall(function ()
            local filename = string.format("%s/%s", self.fileDir, file)
            local shell = string.format("rm %s", filename)
            gLog.i("playerDataFileWriter:loadFile1 shell=", shell)
            local ret = io.popen(shell)
            gLog.i("playerDataFileWriter:loadFile1 shell ret=", ret)
        end, svrFunc.exception)
    end
end

-- 读取redis异常处理文件并落库
function playerDataFileWriter:loadFile2()
    gLog.i("playerDataFileWriter:loadFile2 begin", playerDataCenter.idx)
    local redisLib = require("redisLib")
    -- 校验redis是否异常
    local pcallOk, ok = function ()
        return redisLib:ping()
    end
    gLog.d("playerDataFileWriter:loadFile2 pcallOk=", pcallOk, "ok=", ok)
    if not pcallOk or ok then
        gLog.e("playerDataFileWriter:loadFile2 error: redis exception!")
        return
    end
    -- 遍历读取文件, 并执行文件sql
    local fileArray = {}
    if not lfs.exist(self.fileDir) then
        self.fileDir = lfs.currentdir()
    end
    gLog.i("playerDataFileWriter:loadFile2 fileDir=", self.fileDir, "fileName=", self.fileName)
    for file in lfs.dir(self.fileDir) do
        if string.find(file, self.fileName) then
            table.insert(fileArray, file)
        end
    end
    if #fileArray <= 0 then
        return
    end
    local matchstr = self.fileName .. ".(%d+)-(%d+)-(%d+).(%d+)"
    table.sort(fileArray, function (a, b) -- 文件按时间由早到晚排序
        local y1, m1, d1, i1 = string.match(a, matchstr)
        local y2, m2, d2, i2 = string.match(b, matchstr)
        y1, m1, d1, i1, y2, m2, d2, i2 = tonumber(y1), tonumber(m1), tonumber(d1), tonumber(i1), tonumber(y2), tonumber(m2), tonumber(d2), tonumber(i2)
        -- gLog.d("playerDataFileWriter:loadFile2 sort a=", y1, m1, d1, i1, "b=", y2, m2, d2, i2)
        if y1 and m1 and d1 and i1 and y2 and m2 and d2 and i2 then
            if y1 == y2 then
                if m1 == m2 then
                    if d1 == d2 then
                        return i1 < i2
                    else
                        return d1 < d2
                    end
                else
                    return m1 < m2
                end
            else
                return y1 < y2
            end
        end
    end)
    gLog.i("playerDataFileWriter:loadFile2 #fileArray", #fileArray, table2string(fileArray))
    local successArray = {}
    for _,file in ipairs(fileArray) do
        xpcall(function ()
            local filename = string.format("%s/%s", self.fileDir, file)
            for line in io.lines(filename) do
                local tmp = svrFunc.split(line, "#")
                gLog.i("playerDataFileWriter:loadFile2 do=", file, tmp[1], tmp[2])
                if tmp[1] and tmp[2] then
                    local f = load(tmp[2])
                    if f then
                        skynet.fork(f)
                    end
                end
            end
            table.insert(successArray, file)
        end, svrFunc.exception)
    end
    -- 删除文件
    for _,file in pairs(successArray) do
        xpcall(function ()
            local filename = string.format("%s/%s", self.fileDir, file)
            local shell = string.format("rm %s", filename)
            gLog.i("playerDataFileWriter:loadFile2 shell=", shell)
            local ret = io.popen(shell)
            gLog.i("playerDataFileWriter:loadFile2 shell ret=", ret)
        end, svrFunc.exception)
    end
end

return playerDataFileWriter