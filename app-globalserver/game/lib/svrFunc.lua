--[[
    serviceFunction 公用函数集
--]]
local skynet = require("skynet")
local dbconf = require("dbconf")
local crypt = require("skynet.crypt")

local svrFunc = {}

-- 时间戳转时间信息
function svrFunc.timeStampToTimeInfo(timeStamp)
    local date = os.date("%w %m %d %H:%M:%S %Y", timeStamp)
    local week, mon, day, hour, min, sec, year = string.match(date, "(%d+) (%d+) (%d+) (%d+):(%d+):(%d+) (%d+)")
    local tm = {}
    tm.wday = tonumber(week)
    if tm.wday == 0 then --周天
        tm.wday = 7 
    end 
    tm.mon = tonumber(mon)   
    tm.mday = tonumber(day)
    tm.year = tonumber(year)
    tm.hour = tonumber(hour)
    tm.min = tonumber(min)
    tm.sec = tonumber(sec)
    return tm
end

-- 时间信息转时间戳
function svrFunc.timeInfoToTimeStamp(timeInfo)
    local tb = {
        year = timeInfo.year,
        month = timeInfo.mon,
        day = timeInfo.mday,
        hour = timeInfo.hour,
        min = timeInfo.min,
        sec = timeInfo.sec,
    }
    return os.time(tb)
end

-- 获取开服时间
local openServerTime = {}
function svrFunc.getOpenServerTime(kingdomId)
    if not openServerTime[kingdomId] then
        local openDateSql = "select startTime from conf_kingdom where kid = " .. kingdomId
        local openDate = skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "execute", openDateSql)
        if nil ~= openDate and nil ~= openDate[1] and nil ~= openDate[1].startTime then
            openServerTime[kingdomId] = svrFunc.convertStrTime2OsTime(openDate[1].startTime)
        else    -- 如果发生异常则把当前时间当成开服时间
            openServerTime[kingdomId] = svrFunc.systemTime()
        end
    end
    return openServerTime[kingdomId]
end

--[[
    将一个数组分割成按比例分割成另一个数组, 比如:
    t = { key1, value1, key2, value2 ... }
    keys = { "id", "count" }
    那么
    ret = { { id = key1, count = value1 }, { id = key2, count = value2 } }
--]]
function svrFunc.tableFormat(t, keys)
    local ret = {}
    local n = #keys
    if n <= 0 then
        return t
    end
    local totalNum = #t
    assert(totalNum % n == 0, "配置表和分割数不对应")
    for i = 1, #t, n do
        local d = {}
        for j, key in ipairs(keys) do
            d[key] = t[i + j - 1]
        end
        
        ret[#ret + 1] = d
    end
    
    return ret
end

--[[
    将一个数组分割成按比例分割成map,比如:
    t = { key1, value1, key2, value2 ... }
    那么
    ret = { [key1] = value1, [key2] = value2 }
--]]
function svrFunc.tableFormatToMap(t, transferkeyFun)
    local ret = {}
    local totalNum = #t

    assert(totalNum % 2 == 0, "配置表和分割数不对应")
    for i = 1, #t, 2 do
        local key = t[i]
        if "function" == type(transferkeyFun) then
            key = transferkeyFun(key)
        end
        local value = t[i+1]
        ret[key] = value
    end
    
    return ret
end

local randomSeed
-- 设置随机种子
function svrFunc.setRandomSeed(num)
    randomSeed = num or tostring(svrFunc.systemTime()):reverse():sub(1, 6)
    math.randomseed(randomSeed)
end

function svrFunc.checkRandom(rate)
    local params = {rate,1-rate}
    local ret = svrFunc.randomItem(params)
    if ret == 1 then
        return true
    end
end

function svrFunc.randomItem(params)
    if "table" ~= type(params) or 0 == #params then
        return
    end
    
    if not randomSeed then
        svrFunc.setRandomSeed()
    end
    
    local rates = {}
    local curRate = 0
    local n = 10000
    for i, rate in ipairs(params) do
        curRate = curRate + rate
        rates[i] = curRate * n
    end
    n = rates[#rates]
    local ret = 0
    local random = math.random(1, n)
    for i, rateNum in ipairs(rates) do
    	if random <= rateNum then
    	   ret = i
    	   break
    	end
    end
    
    return ret
end

function svrFunc.random(min, max)
    if not randomSeed then
        svrFunc.setRandomSeed()
    end
    return math.random(min, max)
end

--随机一个范围(min, max)内的数字，和给定的数字(num)比较，如果小于等于为true,大于为false
--min,max默认为（1, 1000）
function svrFunc.isRandomSuccess(num, min, max)
    if not min then
        min = 1
    end
    if not max then
        max = 1000
    end
    if not randomSeed then
        svrFunc.setRandomSeed()
    end
    local randNum = math.random(min, max)
    gLog.d("randNum=", randNum, randomSeed)
    return randNum <= num
end

--随机一个概率范围内的索引
--@rates {100, 200, 700}
function svrFunc.getRandomIndex(rates)
    --计算概率总和
    local totalRate = 0
    for _,rate in pairs(rates) do
        totalRate = totalRate + rate
    end
    if totalRate > 0 then
        local randNum = svrFunc.random(1, totalRate)
        local index = 1
        local curTotalRate = 0
        for _,rate in pairs(rates) do
            curTotalRate = curTotalRate + rate
            if randNum <= curTotalRate then
                return index
            end
            index = index + 1
        end
    end
end

-- 获取系统时间
function svrFunc.systemTime()
    return math.floor(skynet.time())
end

-- 获取系统时间
function svrFunc.skynetTime()
    return skynet.time()
end

-- 从2018.01.01 00:00:00到现在是第几周
function svrFunc.getWeekthFrom20180101(intime)
    --2018.01.01 00:00:00的时间戳,此时刚好是周一
    local begintime = os.time({year=2018, month=1, day=1, hour=0, sec=0})
    local nowtime = intime or os.time()
    local weekth = math.floor((nowtime-begintime)/(7*24*3600)) + 1
    -- print ("weekth=",weekth)
    return weekth
end

-- 模糊对比
-- 返回：true, 优先级 或 false
-- 完全匹配(1) > 其他匹配(2)
function svrFunc.vagueCompare( comStr, origStr )
    if "string" == type(comStr) and "string" == type(origStr) then

        -- 判断是否完全一样
        if comStr == origStr then
            return true, 1
        end

        -- 都转化为小写
        origStr = string.lower(origStr)
        comStr = string.lower(comStr)

        -- 匹配
        local ret = string.match(origStr, "^(" .. comStr .. ")")
        if ret then
            return true, 2
        end
    end

    return false
end

--数组转map
function svrFunc.array2map(tb, keyProp, valueProp)
    local map = {}
    if tb and type(tb) == "table" then
        for _, v in pairs(tb) do
            if v[keyProp] and v[valueProp] then
                map[v[keyProp]] = v[valueProp]
            end
        end
    end
    return map
end

--数组转map
function svrFunc.array2mapWithStrKey(tb, keyProp, valueProp)
    local map = {}
    if tb and type(tb) == "table" then
        for _, v in pairs(tb) do
            if v[keyProp] and v[valueProp] then
                map[tostring(v[keyProp])] = v[valueProp]
            end
        end
    end
    return map
end

--数组转map
function svrFunc.convertMapKey2String(tb)
    if tb and type(tb) == "table" then
        local map = {}
        for k,v in pairs(tb) do
            map[tostring(k)] = v
        end
        return map
    end
    return tb
end

-- 把map的key转成数组
-- convertType => "k"=索引 "v"=值
function svrFunc.getMap2Array(tb, convertType)
    local array = {}
    if type(tb) == "table" and type(convertType) == "string" then
        if convertType == "k" then
            for k,v in pairs(tb) do
                table.insert(array, k)
            end
        elseif convertType == "v" then
            for k,v in pairs(tb) do
                table.insert(array, v)
            end
        end
    end
    
    return array
end

-- 打印异常
function svrFunc.exception(...)
    gLog.e("\nLUA EXCEPTION:", ...)
end

--获取当前时间0点时刻的UTC时间
function svrFunc.getWeehoursUTC()
    local tb = os.date("*t", svrFunc.systemTime())
    tb.hour = 0
    tb.min = 0
    tb.sec = 0
    return os.time(tb)
end

--将字符串的时间格式转化为ostime
function svrFunc.convertStrTime2OsTime(strtime)
    local year,month,day,hour,min,sec = string.match(strtime,"(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    local tb = {
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec,
    }
    return os.time(tb)
end


--判断是否是0或者是nil
function svrFunc.isNilOrZero(value)
    return value == nil or value == 0
end

--map转array并排序
function svrFunc.mapConvertArrayAndSort(map, sortFun)
    local ret = {}
    for _,v in pairs(map) do
        table.insert(ret, v)
    end
    table.sort(ret, sortFun)
    return ret
end

--获取最后指定位数的数字
--@orgValue 原始值
--@digitNum 取最后多少位
function svrFunc.getLastDigit(orgValue, digitNum)
    if not digitNum or type(digitNum) ~= "number" then
        return orgValue
    end
    local ratio = 10^digitNum
    local result = orgValue - math.floor(orgValue / ratio) * ratio
    return result
end

-- 二分查找
-- t 是一个数组，且必须是排序过的数组
function svrFunc.binarySearch(t, element)
    -- 检查参数
    if "table" ~= type(t) then
        gLog.i("bad argument #1 to 'svrFunc.find' (array expected, got " .. type(t) .. ")")
        return
    end

    if #t == 0 then
        gLog.i("bad argument #1 to 'svrFunc.find' (got a empty array)")
        return
    end

    if not element then
        gLog.i("bad argument #2 to 'svrFunc.find' (got a nil")
        return
    end

    local left = 1
    local right = #t
    while left <= right do
        local mid = math.floor((right + left) / 2)
        --gLog.i("mid = ", mid)
        local value = t[mid]
        if element == value then
            return mid
        elseif element < value then
            -- 往左
            right = mid - 1
        elseif element > value then
            -- 往右
            left = mid + 1
        end
    end

    gLog.d("not find " .. element)
end

--判断两个值在不为nil时相等
function svrFunc.isSameButNotNil(v1, v2)
    if not svrFunc.isNilOrZero(v1) and not svrFunc.isNilOrZero(v2) and v1 == v2 then
        return true
    else
        return false
    end
end


--获取和当前时间的差值
function svrFunc.getTimeDiffWithCurTime(year, month, day, hour, min, sec)
    local tab = {year=year or 2015, month=month or 1, day=day or 1, hour=hour or 0,min=min or 0,sec=sec or 0,isdst=false}
    local time1 = os.time(tab)
    local time = svrFunc.systemTime()
    return time1-time
end

function svrFunc.table_copy_table(ori_tab)
    if (type(ori_tab) ~= "table") then
        return nil
    end
    local new_tab = {}
    for i,v in pairs(ori_tab) do
        local vtyp = type(v)
        if (vtyp == "table") then
            new_tab[i] = svrFunc.table_copy_table(v)
        elseif (vtyp == "thread") then
            new_tab[i] = v
        elseif (vtyp == "userdata") then
            new_tab[i] = v
        else
            new_tab[i] = v
        end
    end
    return new_tab
end

-- 获取星期天数
--[[
    星期一：1
    星期二：2
    星期三：3
    星期四：4
    星期五：5
    星期六：6
    星期天：7
--]]
function svrFunc.getWeekDay(time)
    time = time or svrFunc.systemTime()
    local weekDay = tonumber(os.date("%w", time))
    if weekDay == 0 then
        weekDay = 7
    end
    return weekDay
end

-- 获取上个小时开始时的UTC
function svrFunc.getPreHourUTC(time)
    time = time or svrFunc.systemTime()
    local m = tonumber(os.date("%M", time))
    local s = tonumber(os.date("%S", time))
    return time - ( m * 60 + s )
end

-- 获取下个小时开始时的UTC
function svrFunc.getNextHourUTC(time)
    time = time or svrFunc.systemTime()
    local m = tonumber(os.date("%M", time))
    local s = tonumber(os.date("%S", time))
    return time + ( (59 - m) * 60 + (60 - s) )
end

--获取前5分钟(能被5整除,如:5,10,15...)
function svrFunc.getPre5MinUTC(time)
    time = time or svrFunc.systemTime()
    local m = tonumber(os.date("%M", time))
    local s = tonumber(os.date("%S", time))
    if m % 5 == 0 then
        time = time - s
    else
        local preMin = m - math.floor(m/5) * 5
        time = time - (  preMin * 60 + s  )
    end
    return time
end

--[[
    获取下个星期的UTC零时

    -- 星期
    gWeekDay = {
        MONDAY = 1,
        TUESDA = 2,
        WEDNESDAY = 3,
        THURSDAY = 4,
        FRIDAY = 5,
        SATURDAY = 6,
        SUNDAY = 7,
    }
--]]
function svrFunc.getNextWeekDayUTC(nextWeekDay)
    if "number" ~= type(nextWeekDay) or nextWeekDay < 1 or nextWeekDay > 7 then
        return nil
    end

    -- 获取当前时间第二天 00:00:00 时的秒数
    local sec0 = svrFunc.getTomorrowZeroHourUTC()
    local secOfOneDay = 24 * 60 * 60

    local weekDay = svrFunc.getWeekDay(sec0)
    if nextWeekDay == weekDay then
        return sec0
    elseif weekDay < nextWeekDay then
        return sec0 + secOfOneDay * (nextWeekDay - weekDay)
    elseif weekDay > nextWeekDay then
        return sec0 + secOfOneDay * (gWeekDay.SUNDAY - weekDay + nextWeekDay )
    end
end

--[[
    获取本周某个星期的UTC零时

    -- 星期
    gWeekDay = {
        MONDAY = 1,
        TUESDA = 2,
        WEDNESDAY = 3,
        THURSDAY = 4,
        FRIDAY = 5,
        SATURDAY = 6,
        SUNDAY = 7,
    }
--]]
function svrFunc.getCurWeekDayUTC(curWeekDay)
    if "number" ~= type(curWeekDay) or curWeekDay < 1 or curWeekDay > 7 then
        return nil
    end

    -- 获取当前时间 00:00:00 时的秒数
    local curTimeZero = svrFunc.getTodayZeroHourUTC()

    local secOfOneDay = 24 * 60 * 60

    local weekDay = svrFunc.getWeekDay(curTimeZero)
    if curWeekDay == weekDay then
        return curTimeZero
    elseif weekDay < curWeekDay then
        return curTimeZero + secOfOneDay * (curWeekDay - weekDay)
    elseif weekDay > curWeekDay then
        return curTimeZero - secOfOneDay * (weekDay - curWeekDay )
    end
end

--[[
    获取上个星期的UTC零时

    -- 星期
    gWeekDay = {
        MONDAY = 1,
        TUESDA = 2,
        WEDNESDAY = 3,
        THURSDAY = 4,
        FRIDAY = 5,
        SATURDAY = 6,
        SUNDAY = 7,
    }
--]]
function svrFunc.getPreWeekDayUTC(preWeekDay)
    if "number" ~= type(preWeekDay) or preWeekDay < 1 or preWeekDay > 7 then
        return nil
    end

    -- 获取当前时间第二天 00:00:00 时的秒数
    local sec0 = svrFunc.getTodayZeroHourUTC()
    local secOfOneDay = 24 * 60 * 60

    local weekDay = svrFunc.getWeekDay(sec0)
    if preWeekDay == weekDay then
        return sec0
    elseif weekDay < preWeekDay then
        return sec0 - secOfOneDay * (gWeekDay.SUNDAY - preWeekDay + weekDay )
    elseif weekDay > preWeekDay then
        return sec0 - secOfOneDay * (weekDay - preWeekDay)
    end
end


function svrFunc.getYesterdayWeekDay()
    local weekDay = svrFunc.getWeekDay()
    if weekDay == 1 then
        return 7
    else
        return weekDay - 1
    end
end

-- 两个时间对比，是否在同一天
-- time2 默认为当前时间
function svrFunc.isSameDay( time1, time2 )
    time2 = time2 or svrFunc.systemTime()

    local day1 = os.date("%d", time1)
    local day2 = os.date("%d", time2)
    if day1 ~= day2 then
        return false
    end

    local mon1 = os.date("%m", time1)
    local mon2 = os.date("%m", time2)
    if mon1 ~= mon2 then
        return false
    end

    local year1 = os.date("%Y", time1)
    local year2 = os.date("%Y", time2)
    if year1 ~= year2 then
        return false
    end

    return true
end

-- 获取某一时间当天零时UTC
function svrFunc.getTodayZeroHourUTC(time)
    time = time or svrFunc.systemTime()
    -- 获取当前时间的时分秒
    local h = tonumber(os.date("%H", time))
    local m = tonumber(os.date("%M", time))
    local s = tonumber(os.date("%S", time))
    return time - ( h * 3600 + m * 60 + s )
end

-- 获取某一时间第二天零时UTC
function svrFunc.getTomorrowZeroHourUTC(time)
    time = time or svrFunc.systemTime()
    -- 获取当前时间的时分秒
    local h = tonumber(os.date("%H", time))
    local m = tonumber(os.date("%M", time))
    local s = tonumber(os.date("%S", time))
    return time + ( (23 - h) * 3600 + (59 - m) * 60 + (60 - s) )
end

-- 两个时间对比，是否是连续的两天
function svrFunc.differOneDay(time1, time2)
    -- 检查参数
    if not time1 then return end
    -- time2 默认当前时间
    time2 = time2 or svrFunc.systemTime()
    -- time1 一定要比 time2 小
    if time1 > time2 then
        time1, time2 = time2, time1
    end

    -- 1.判断今日是否已经登陆
    local ret = svrFunc.isSameDay(time1, time2)
    if ret then
        return false, 0
    end

    -- 判断两个时间相差是否超过一天
    -- 获取当前时间的时分秒
    local h = os.date("%H", time2)
    local m = os.date("%M", time2)
    local s = os.date("%S", time2)
    -- 获取 time2 00:00:00时的秒数
    local sec0 = time2 - ( h * 3600 + m * 60 + s )
    -- 上次登陆到今日零时，经过的秒数
    local passSecond = sec0 - time1
    -- 判断秒数是否超过一天
    local secOfOneDay = 24 * 60 * 60
    if passSecond <= secOfOneDay then
        -- 不超过一天，是连续的两天
        return true, 1
    else
        -- 超过一天，非连续的两天
        return false, math.ceil(passSecond / secOfOneDay)
    end
end

-- 发送httppost
function svrFunc.httpPost(host, data, url)
    --gLog.i("svrFunc.httpPost(host, url, data)", host, url, data)
    local httpc = require "http.httpc"
    url = url or "/"
    local recvheader = {}
    local header = {
        ["content-type"] = "application/x-www-form-urlencoded"
    }
    local status, body = httpc.request("POST", host, url, recvheader, header, data)
    --gLog.dump(status, "http status=", 10)
    --gLog.dump(body, "http body=", 10)
    local isSuccess = (tostring(status) == "200")
    return isSuccess, body
end


-- 匹配阿拉伯字符数字英文字母
function svrFunc.matchArabCharNum(str)
    local regx = "^[\216\128-\216\191a-z\217\128-\217\191A-Z\218\128-\218\1910-9\219\128-\219\191]+$"
    local ret = string.match(str, regx)
    if ret then
        return true, ret
    else
        return false
    end
end

-- 按utf8分割字符串为数组
function svrFunc.convertStringToArray(input)
    if "string" ~= type(input) and string.len(input) > 0 then
        return {input}
    end

    local array = {}
    local len  = string.len(input)
    local pos = 1
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while 0 < pos and pos <= len do
        local tmp = string.byte(input, pos)
        local i = #arr
        while arr[i] do
            if tmp >= arr[i] then
                local c = string.sub(input, pos, pos + i - 1)
                table.insert(array, c)
                pos = pos + i
                break
            end
            i = i - 1
        end
    end

    return array
end

function svrFunc.decodeURL(s)
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    return s
end

function svrFunc.encodeURL(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

--将格式字符串转化为lua table,如："1,2,3,4"=>{1,2,3,4}
function svrFunc.formatStr2Table(str)
    local ret = {}
    for w in string.gmatch(str,"%w+") do
        table.insert(ret,w)
    end
    return ret
end

--[[
    正数的十进制(数字)转成二进制(字符串)
--]]
function svrFunc.convertToBinary(ten)
    if "number" == type(ten) and ten > 0 then
        local ary = {}
        while ten > 0 do
            table.insert(ary, ten%2)
            ten = math.floor(ten/2)
        end

        local two = ""
        for i=#ary, 1, -1 do
            two = two .. ary[i]
        end

        -- gLog.i("two=", two)
        return two
    end
end

--[[
    二进制(字符串)转成十进制(数字)
--]]
function svrFunc.convertToTen(two)
    if "string" == type(two) and string.len(two) > 0 then
        -- math.pow 提示没有该函数 郁闷
        local function pow(x, y)
            local ret = 1
            for i=1, y do
                ret = ret * x
            end
            return ret
        end

        local ten = 0
        local len = string.len(two)
        for i=1, len do
            local num = string.sub(two, i, i)
            if 0 == tonumber(num) or 1 == tonumber(num) then
                -- gLog.i("len-i", len-i)
                -- ten = ten + tonumber(num) * math.pow(2, len-i)
                ten = ten + tonumber(num) * pow(2, len-i)
            else
                gLog.i("svrFunc.convertToTen: not 0 or 1")
                return nil
            end
        end

        ten = math.floor(ten)
        -- gLog.i("ten=", ten)
        return ten
    end
end

--[[
    反码转化：二进制(字符串)转成二进制(字符串)
--]]
function svrFunc.convertToInverse(two)
    if "string" == type(two) and string.len(two) > 0 then
        local result = ""
        local len = string.len(two)

        for i=1, len do
            local num = string.sub(two, i, i)
            if 0 == tonumber(num) then
                result = result .. "1"
            elseif 1 == tonumber(num) then
                result = result .. "0"
            else
                gLog.i("svrFunc.convertToInverse: not 0 or 1")
                return nil
            end         
        end
        return result
    end
end

--[[
    正数的十进制(数字)转成十六进制(字符串)
--]]
function svrFunc.tenToSixteen(ten)
    if 0 == ten then
        return "0"
    elseif "number" == type(ten) and ten > 0 then
        local ary = {}
        while ten > 0 do
            table.insert(ary, ten%16)
            ten = math.floor(ten/16)
        end
        local indexAry = {}
        indexAry[10] = "a"
        indexAry[11] = "b"
        indexAry[12] = "c"
        indexAry[13] = "d"
        indexAry[14] = "e"
        indexAry[15] = "f"

        local sixteen = ""
        for i=#ary, 1, -1 do
            if tonumber(ary[i]) >= 10 then
                sixteen = sixteen .. indexAry[tonumber(ary[i])]
            else
                sixteen = sixteen .. ary[i]
            end
        end
        -- gLog.i(sixteen)
        return sixteen
    end
end

function svrFunc.fileExists(path)
    local file = io.open(path, "rb")
    if file then 
        file:close() 
    end
    gLog.i("svrFunc.fileExists(path)",path, file)
    return file ~= nil
end

--深度合并
function svrFunc.deepMerge(dest, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if not dest[k] then
                dest[k] = v
            elseif type(dest[k]) == "table" then
                svrFunc.deepMerge(dest[k], v)
            else
                gLog.i("svrFunc.deepMerge type not same")
            end
        else
            dest[k] = v
        end
    end
end

--内存回收
function svrFunc.memoryRecovery()
    --gLog.dump(collectgarbage("count"), "collectgarbage start", 10)
    skynet.send(skynet.self(),"debug", "GC")
    --gLog.dump(collectgarbage("count"), "collectgarbage end", 10)
end

--分割字符串
function svrFunc.split(szFullString, szSeparator)
    local nSplitArray = {}  
    if type(szFullString) == "string" then
        local nFindStartIndex = 1  
        local nSplitIndex = 1  
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
    end
    return nSplitArray  
end

function svrFunc.splitPlateformInfo(plateform)
    return table.unpack(svrFunc.split(plateform, " "))
end

function svrFunc.splitAddr(addr)
    local arr = svrFunc.split(addr, ":")
    if #arr > 0 then
        return arr[1]
    end
end

--转移
function svrFunc.escape(str)
    local result
    local mysql = require("mysql")
    if str then
        local str = mysql.quote_sql_str(str)
        local strLen = string.len(str)
        if strLen > 2 then
            result = string.sub(str, 2, strLen - 1)
        else
            result = ""
        end
    end
    return result
end

-- 获取当前日期
function svrFunc.getCurDayInYear(time)
    if not time then
        time = os.time()
    end
    local temp = os.date("*t", os.time())
    return temp.day
end

-- 获取当前日期
function svrFunc.getCurDate(time)
    if not time then
        time = os.time()
    end
    
    -- 判断两个时间相差是否超过一天
    -- 获取当前时间的时分秒
    local h = os.date("%H", time)
    local m = os.date("%M", time)
    local s = os.date("%S", time)
    -- 获取 time 00:00:00时的秒数
    local sec0 = time - ( h * 3600 + m * 60 + s )
    return sec0
end

--[[
    四舍五入

    @param num 整数
    @param pos 保留小数位
--]]
function svrFunc.rounding(num, pos)
    if "number" ~= type(num) then
        -- print("svrFunc.rounding: num is not a number!")
        return num
    end

    pos = pos or 0
    if "number" ~= type(pos) then
        -- print("svrFunc.rounding: pos is not a number!")
        return num
    end

    if pos < 0 then
        -- print("svrFunc.rounding: pos is lowwer than 0!")
        return num
    end

    local n = 10^(-pos) / 2
    if num < 0 then
        n = -n
    end
    -- print("n = ", n)
    num = num + n
    -- print("num + n = ", num)
    if pos == 0 then
        num = math.floor(num)
        -- print("math.floor(num)", num)
    else
        num = tonumber(string.format("%."..pos.."f", num))
        -- print([[string.format("%f", num)]], num)math.floor(num)
    end
    

    return num
end

--[[
    skynet.call 超时调用

    @param time         number          超时时间，单位秒
    @param timeoutCall  true or false   超时是否调用 callback 函数
    @param callback     function        回调函数
        该函数的参数： ok, ... = 是否未超时, skynet.call 返回值，例如
        function callback(ok, ...)
            if ok then
                -- 未超时
            else
                -- 超时
            end
        end

        注意，在 callback 函数中处理业务时，注意数据状态，小心重入

    @param ... skynet.call 调用需要的参数

    @return true    不超时
    @return false   超时
--]]
function svrFunc.timeoutSkynetCall( time, timeoutCall, callback, ... )
    local timeout = false
    local ok = false
    local co = coroutine.running()

    skynet.fork(function (...)
        local function f( ... )
            if not timeout then
                ok = true
                skynet.wakeup(co)
            end
            if timeout then
                if timeoutCall then
                    callback(ok, ...)
                end
            else
                callback(ok, ...)
            end
        end
        f(skynet.call(...))
    end, ...)


    skynet.sleep(time * 100)
    timeout = true

    return ok
end

-- 设置key
function svrFunc.generateKey()
    if not svrFunc.exchangekey then
        local key = {77, 86, 130, 120, 96, 45, 48, 85}
        local offset = {5, 2, 8, 5, 6, 3, 2, 9}
        local keytab = {}
        local tableinsert = table.insert
        for i,v in ipairs(key) do
            code = v - offset[i]*offset[2]
            tableinsert(keytab,1,string.char(code))
        end
        svrFunc.exchangekey = table.concat(keytab)
    end
    return svrFunc.exchangekey
end

--[[解密
mContent--字符串
]]
function svrFunc.decryptData(mCryptContent)
    if not mCryptContent then
        return
    end
    local key = svrFunc.generateKey()
    local decrypt = crypt.desdecode(key, crypt.hexdecode(mCryptContent))
    return decrypt
end

--[[加密
mContent--字符串
]]
function svrFunc.encryptData(mContent)
    if not mContent then
        return 
    end
    local key = svrFunc.generateKey()
    local c = crypt.desencode(key, mContent)
    return crypt.hexencode(c)
end

--[[合并奖励
        reward结构见sMailExtra定义, 注意ret将被改变
]]
function svrFunc.mergeReward(ret, reward)
    if not ret then
        ret = {}
    end
    -- 合并道具
    if reward.items and next(reward.items) then
        if not ret.items then
            ret.items = {}
        end
        local find = false
        for k,v in pairs(reward.items) do
            if v.id and v.count then
                find = false
                for kk,vv in pairs(ret.items) do
                    if vv.id == v.id then
                        vv.count = vv.count + v.count
                        find = true
                        break
                    end
                end
                if not find then
                    table.insert(ret.items, {id = v.id, count = v.count})
                end
            end
        end
    end
    return ret
end

--[[发送奖励统一入口
        reward结构见sMailExtra定义
]]
function svrFunc.sendReward(player, reward)
    if not player or type(reward) ~= "table" then
        return
    end
    -- 道具
    if reward.items and next(reward.items) then
        local backpackCtrl = player:getModule(gModuleDef.backpackModule)
        backpackCtrl:addItems(reward.items)
    end
end

-- 判断2个table数据是否完全一致(注意：tab不能自循环, 不要有元表)
function svrFunc.equalTab(tab1, tab2)
    if type(tab1) == "table" and type(tab2) == "table" then
        if table.nums(tab1) ~= table.nums(tab2) then
            return false
        end
        for k,v in pairs(tab1) do
            if type(v) == "table" then
                if type(tab2[k]) == "table" then
                    if table.nums(v) ~= table.nums(tab2[k]) then
                        return false
                    end
                    local equ = svrFunc.equalTab(v, tab2[k])
                    if not equ then
                        return false
                    end
                else
                    return false
                end
            elseif v ~= tab2[k] then
                return false
            end
        end
        return true
    end
    return false
end

-- 向下取整
function svrFunc.floor(x)
    local ceilx = math.ceil(x)
    local offset = ceilx - x
    if offset <= 0.000001 and offset >= -0.000001 then
        return ceilx
    elseif offset > 0 then
        return ceilx - 1
    else
        return ceilx
    end
end

--[[常用变量缓存, 以提高性能
]]
svrFunc.emptyTb = {} -- 空表

return svrFunc
