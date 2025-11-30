--[[
    玩家数据中心服务中心
]]
local skynet = require("skynet")
local skynetQueue = require("skynet.queue")
local svrAddrMgr = require("svrAddrMgr")
local json = require("json")
local svrFunc = require("svrFunc")
local playerDataLib = require("playerDataLib")
local playerDataConfig = require("playerDataConfig")
local serviceCenterBase = require("serviceCenterBase2")
local playerDataCenter = class("playerDataCenter", serviceCenterBase)

local gRedisType, gLog, string, type, next, pairs, xpcall, assert, tonumber, tostring = gRedisType, gLog, string, type, next, pairs, xpcall, assert, tonumber, tostring

function playerDataCenter:ctor()
    playerDataCenter.super.ctor(self)
    
    -- 调用异常需返回特殊标识, 注意数据重置风险
    self.errd = "__errd__"

    -- redis更新任务列表
    self.redisTask = require("filterList").new()
    -- mysql/mongodb更新任务列表
    self.dbTask = require("filterList").new()
    -- 串行队列
    self.sq = {}
end

-- 初始化
function playerDataCenter:init(kid, idx)
    gLog.i("==playerDataCenter:init begin==", kid, idx)
    playerDataCenter.super.init(self, kid)

    -- 服务ID
    self.idx = idx

    -- 创建模块
    if dbconf.dbtype == "mongodb" then
        self.dbWrap = require("dbWrap.mongodbWrap").new(self, dbconf.dbtype, dbconf.mongodb_confdb, dbconf.mongodb_gamedb)
    elseif dbconf.dbtype == "mysql" then
        self.dbWrap = require("dbWrap.mysqlWrap").new(self, dbconf.dbtype, dbconf.mysql_confdb, dbconf.mysql_gamedb)
    else
        assert(false, "playerDataCenter:init error: dbtype no support, dbtype="..tostring(dbconf.dbtype))
    end
    self.playerDataCache = require("playerDataCache").new()
    self.playerDataTimer = require("playerDataTimer").new()

    -- 初始化
    self.playerDataTimer:init()

    -- 订阅redis玩家王国KID变更频道
    self:subscribe()

    gLog.i("==playerDataCenter:init end==", kid, idx)
end

-- 停止服务
function playerDataCenter:stop()
    gLog.i("==playerDataCenter:stop begin==", self.kid, self.idx)
    -- 标记停服中
    if self.stoping then
        return
    end
    self.stoping = true
    -- 等待所有任务队列都处理完, 再标记已停服
    skynet.fork(function()
        self.playerDataTimer:stop()
        while(true) do
            if self.redisTask:count() <= 0 and self.dbTask:count() then
                -- 检查消息队列和协程
                local mqlen = skynet.mqlen() or 0
                local task = {}
                local taskLen = skynet.task(task) or 0
                if mqlen > 0 or taskLen > 0 then
                    gLog.i("playerDataCenter:stop waiting mq and task, mqlen=", mqlen, "taskLen=", taskLen, "task=", table2string(task))
                else
                    --gLog.i("playerDataCenter:stop waiting mq and task, mqlen=", mqlen, "taskLen=", taskLen, "task=", table2string(task))
                    break
                end
                break
            end
            skynet.sleep(200)
        end
        -- 标记已停服
        self.stoped = true
        if self.myTimer then
            self.myTimer:pause()
        end
    end)
    gLog.i("==playerDataCenter:stop end==", self.kid, self.idx)
end

-- 获取玩家当前所在王国KID
function playerDataCenter:getKidOfUid(uid)
    return playerDataLib:getKidOfUid(self.kid, uid)
end

-- 设置玩家当前所在王国KID
function playerDataCenter:setKidOfUid(uid, kid)
    playerDataLib:setKidOfUid(uid, kid, nil)
end

-- 获取联盟当前所在王国KID
function playerDataCenter:getKidOfAid(aid)
    return playerDataLib:getKidOfAid(self.kid, aid)
end

--[[
    查询
    @id             [必填]数据ID
    @module         [必填]数据名
    @custom         [选填]根据多个条件查询
    @force          [选填]查询跨服数据时, 是否强制查询
    示例:
        1. playerDataLib:query(1, 1201, "lordinfo")
        2. playerDataLib:query(1, 1201, "lordinfo", {"_id":1001})
]]
function playerDataCenter:query(id, module, custom, force)
    assert(id and module, "playerDataCenter:query error: id or module is nil")
    local sq = self:getSq(id, module)
    return sq(function()
        gLog.d("playerDataCenter:query=", id, module, custom, force)
        -- 获取当前所在王国KID
        local kid = self.kid
        local redisType = playerDataConfig:getRedisType(module)
        if redisType == gRedisType.player then
            kid = playerDataLib:getKidOfUid(self.kid, id)
        elseif redisType == gRedisType.alliance then
            kid = playerDataLib:getKidOfAid(self.kid, id)
        end
        -- 校验参数
        if not kid or not id or not module or not playerDataConfig.moduleSettings[module] then
            svrFunc.exception(string.format("playerDataCenter:query error1: kid=%s, id=%s, module=%s", kid, id, module))
            return
        end
        local data = nil
        -- 先查询缓存
        if kid == self.kid or not force then
            -- 需提前处理redis更新任务
            self:dealRedisTask(id, module)
            data = self.playerDataCache:query(kid, id, module)
        end
        if data ~= nil then
            return data
        end
        -- 若是本王国数据, 查询mysql，然后更新redis和内存缓存; 若非本王国数据, 跨服调用查询, 然后更新redis和内存缓存。
        if kid == self.kid then
            -- 需提前处理更新任务
            self:dealDbTask(id, module)
            -- 执行查询
            data = self.dbWrap:query(kid, id, module, custom)
        else
            data = playerDataLib:query(kid, id, module, custom, force)
            if data ~= nil then
                self.playerDataCache:update(kid, id, module, data, false)
            end
        end
        return data
    end)
end

--[[
    更新(同步)
    @id             [必填]数据ID
    @module         [必填]数据名
    @data           [必填]数据
    示例:
        1. playerDataLib:update(1, 1201, "lordinfo", {_id = 1201, name = "ABC"})
]]
function playerDataCenter:update(id, module, data)
    local sq = self:getSq(id, module)
    return sq(function()
        gLog.d("playerDataCenter:update", id, module, data)
        -- 获取当前所在王国KID
        local kid = self.kid
        local redisType = playerDataConfig:getRedisType(module)
        if redisType == gRedisType.player then
            kid = playerDataLib:getKidOfUid(self.kid, id)
        elseif redisType == gRedisType.alliance then
            kid = playerDataLib:getKidOfAid(self.kid, id)
        end
        -- 不能在本王国更新别王国的数据
        if not kid or kid ~= self.kid or not id or not module or data == nil or not playerDataConfig.moduleSettings[module] then
            svrFunc.exception(string.format("playerDataCenter:update error1: kid=%s, id=%s, module=%s", kid, id, module))
            return false
        end
        -- 需提前处理redis更新任务
        xpcall(function ()
            self:dealRedisTask(id, module, "update") 
        end, svrFunc.exception)
        -- 执行更新
        return self.dbWrap:update(kid, id, module, data)
    end)
end

--[[
    更新(异步)
    @id             [必填]数据ID
    @module         [必填]数据名
    @data           [必填]数据
    @custom          [选填]是否复杂更新: 为true时, 可同时更新多个字段, data中非空字段都需要传
    示例:
        1. sendUpdate(1, 1201, "lordinfo", {uid = 1201, name = "ABC"})
        2. sendUpdate(1, 1201, "lordinfo", {id = 1201, data = {uid = 1201, name = "ABC"}}, true)
]]
function playerDataCenter:sendUpdate(id, module, data, custom)
    local sq = self:getSq(id, module)
    return sq(function()
        -- 获取当前所在王国KID
        gLog.d("playerDataCenter:sendUpdate", id, module, data, custom)
        -- 获取当前所在王国KID
        local kid = self.kid
        local redisType = playerDataConfig:getRedisType(module)
        if redisType == gRedisType.player then
            kid = playerDataLib:getKidOfUid(self.kid, id)
        elseif redisType == gRedisType.alliance then
            kid = playerDataLib:getKidOfAid(self.kid, id)
        end
        -- 不能在本王国更新别王国的数据
        if not kid or kid ~= self.kid or not id or not module or data == nil or not playerDataConfig.moduleSettings[module] then
            svrFunc.exception(string.format("playerDataCenter:sendUpdate error: kid=%s, id=%s, module=%s", kid, id, module))
            return
        end
        -- 需提前处理redis更新任务
        xpcall(function ()
            self:dealRedisTask(id, module, "update")
        end, svrFunc.exception)
        -- 执行更新
        self.dbWrap:sendUpdate(kid, id, module, data, custom)
    end)
end

--[[
    删除
    @kid            [必填]数据王国ID
    @id             [必填]数据ID
    @module         [必填]数据名
    @custom         [选填]根据多个条件删除
    示例:
        1. delete(1, 1201, "lordinfo")
        2. delete(1, 1201, "lordinfo", {id = 1201,})
]]
function playerDataCenter:delete(id, module, custom)
    local sq = self:getSq(id, module)
    return sq(function()
        gLog.d("playerDataCenter:delete", id, module, custom)
        -- 获取当前所在王国KID
        local kid = self.kid
        local redisType = playerDataConfig:getRedisType(module)
        if redisType == gRedisType.player then
            kid = playerDataLib:getKidOfUid(self.kid, id)
        elseif redisType == gRedisType.alliance then
            kid = playerDataLib:getKidOfAid(self.kid, id)
        end
        -- 不能在本王国删除别王国的数据
        if not kid or kid ~= self.kid or not id or not module or not playerDataConfig.moduleSettings[module] then
            svrFunc.exception(string.format("playerDataCenter:delete error1: kid=%s, id=%s, module=%s", kid, id, module))
            return
        end
        -- 需提前处理redis更新任务
        xpcall(function ()
            self:dealRedisTask(id, module, "delete")
        end, svrFunc.exception)
        -- 执行删除
        return self.dbWrap:delete(kid, id, module, custom)
    end)
end

--[[
    删除(异步)
    @kid            [必填]数据王国ID
    @id             [必填]数据ID
    @module         [必填]数据名
    @custom          [选填]根据多个条件删除
    示例:
        1. sendDelete(1, 1201, "lordinfo")
        2. sendDelete(1, 1201, "lordinfo", {id = 1201,})
]]
function playerDataCenter:sendDelete(id, module, custom)
    local sq = self:getSq(id, module)
    return sq(function()
        gLog.d("playerDataCenter:sendDelete", id, module, custom)
        -- 获取当前所在王国KID
        local kid = self.kid
        local redisType = playerDataConfig:getRedisType(module)
        if redisType == gRedisType.player then
            kid = playerDataLib:getKidOfUid(self.kid, id)
        elseif redisType == gRedisType.alliance then
            kid = playerDataLib:getKidOfAid(self.kid, id)
        end
        -- 不能在本王国删除别王国的数据
        if not kid or kid ~= self.kid or not id or not module or not playerDataConfig.moduleSettings[module] then
            svrFunc.exception(string.format("playerDataCenter:sendDelete error: kid=%s, id=%s, module=%s", kid, id, module))
            return
        end
        -- 需提前处理redis更新任务
        xpcall(function ()
            self:dealRedisTask(id, module, "delete")
        end, svrFunc.exception)
        -- 执行删除
        return self.dbWrap:sendDelete(kid, id, module, custom)
    end)
end

-- 执行sql(非安全)
function playerDataCenter:executeSql(...)
    return self.dbWrap:executeSql(...)
end

-- 执行sql(安全的)
-- @id & module 数据ID&数据数据名, 两者都传时, 可以在内存耗尽crash前异常处理
function playerDataCenter:executeSqlSafe(...)
    return self.dbWrap:executeSqlSafe(...)
end

-- 任务key
function playerDataCenter:getTaskKey(id, module)
    return string.format("%s-%s", id, module)
end

-- 定时处理mysql更新任务列表(类漏桶排队算法)
function playerDataCenter:onDealDbTask()
    -- if self.idx == 1 then
    --     gLog.d("playerDataCenter:onDealDbTask begin=", self.idx, self.dbTask:count())
    -- end
    if self.dbTask:count() > 0 and self.dbWrap:isDbAlive() then
        local opt, time = 0, skynet.time()
        while(true) do
            local task = self.dbTask:pop()
            if task then
                opt = opt + 1
                -- gLog.d("playerDataCenter:onDealDbTask do=", opt, task.id, task.module, task.cmd, "sql=", task.sql)
                local sq = self:getSq(task.id, task.module)
                sq(function()
                    self:executeSqlSafe(task.cmd or task.sql, task.id, task.module, task.data, task.custom)
                end)
                if opt%100 == 0 then -- 每处理100个, 睡眠2/100秒(20ms), 单个service每秒处理上限100*100/2 = 5000, 8个service每秒处理上限4w, 需根据mysql的qps来调整(rok全服实时在线1w+,阿里云QPS峰值5000左右,平均300)
                    if opt > 50000 then -- 任务队列爆炸, 可能是db爆了, 报错跳出
                        svrFunc.exception(string.format("playerDataCenter:onDealDbTask error: task overload, opt=%d", opt))
                        break
                    end
                    skynet.sleep(2)
                end
                if (task.time or time) >= time then
                    break
                end
            else
                -- 任务队列全部处理完成, 跳出
                break
            end
        end
    end
    if self.idx == 1 then
        gLog.d("playerDataCenter:onDealDbTask end=", self.idx, self.dbTask:count())
    end
end

-- 提前处理mysql更新任务
function playerDataCenter:dealDbTask(id, module)
    local taskKey = self:getTaskKey(id, module)
    if self.dbTask:has(taskKey) and self.dbWrap:isDbAlive() then
        local task = self.dbTask:remove(taskKey)
        if task then
            self:executeSqlSafe(task.sql, id, module)
        end
    end
end

-- 定时处理redis更新任务列表(类漏桶排队算法)
function playerDataCenter:onDealRedisTask()
    -- if self.idx == 1 then
    --     gLog.d("playerDataCenter:onDealRedisTask begin=", self.idx, self.redisTask:count())
    -- end
    if self.redisTask:count() > 0 and self.playerDataTimer:isRedisAlive() then
        local opt, time = 0, skynet.time()
        while(true) do
            local task = self.redisTask:pop()
            if task then
                opt = opt + 1
                gLog.d("playerDataCenter:onDealRedisTask do=", opt, task.id, task.module, task.cmd, table2string(task.data))
                local sq = self:getSq(task.id, task.module)
                sq(function()
                    if task.cmd == "update" then
                        self.dbWrap:update(task.kid, task.id, task.module, task.data)
                    elseif task.cmd == "delete" then
                        self.dbWrap:delete(task.kid, task.id, task.module, task.custom)
                    else
                        assert(false, "playerDataCenter:onDealRedisTask unknown cmd"..tostring(task.cmd))
                    end
                end)
                if opt%100 == 0 then -- 每处理100个, 睡眠2/100秒(20ms), 单个service每秒处理上限100*100/2 = 10000, 8个service每秒处理上限8w, 需根据redis的qps来调整(redis的qps一般能达到10w-15w)
                    if opt > 50000 then -- 任务队列爆炸, 可能是redis爆了, 报错跳出
                        svrFunc.exception(string.format("playerDataCenter:onDealRedisTask error: task overload, opt=%d", opt))
                        break
                    end
                    skynet.sleep(1)
                end
                if (task.time or time) >= time then
                    break
                end
            else
                -- 任务队列全部处理完成, 跳出
                break
            end
        end
    end
    -- if self.idx == 1 then
    --     gLog.d("playerDataCenter:onDealRedisTask end=", self.idx, self.redisTask:count())
    -- end
end

-- 处理redis更新任务
function playerDataCenter:dealRedisTask(id, module, cmd)
    local taskKey = self:getTaskKey(id, module)
    local task = self.redisTask:get(taskKey) 
    if task and task.cmd ~= cmd and self.playerDataTimer:isRedisAlive() then
        task = self.redisTask:remove(taskKey)
        if task then
            if task.cmd == "update" then
                self.dbWrap:update(task.kid, task.id, task.module, task.data)
            elseif task.cmd == "delete" then
                self.dbWrap:delete(task.kid, task.id, task.module, task.custom)
            end
        end
    end
end

-- 玩家/联盟彻底离线(数据落地)
-- @newKid 迁服时传, 同时删除本地redis数据
function playerDataCenter:logout(uid, newKid)
    gLog.i("playerDataCenter:logout begin=", uid, newKid)
    local f = function(id, tp)
        for k,v in pairs(playerDataConfig.moduleSettings) do
            if v.redisType == tp then
                local taskKey = self:getTaskKey(id, v.table)
                if self.redisTask:has(taskKey) or self.dbTask:has(taskKey) then
                    gLog.i("playerDataCenter:logout do=", id, v.table)
                    local sq = self:getSq(id, v.table)
                    sq(function()
                        self:dealRedisTask(id, v.table)
                        self:dealDbTask(id, v.table)
                    end)
                end
            end
        end
        -- 删除该玩家/联盟所有sq, 防止泄漏
        for k,v in pairs(playerDataConfig.moduleSettings) do
            if v.redisType == tp then
                local key = self:getTaskKey(id, v.table)
                self:delSq(key)
            end
        end
        -- 迁服时删除本地redis的玩家数据
        if newKid and newKid > 0 then
            if tp == gRedisType.player then
                local redisLib = require("redisLib")
                local key = tp.key(self.kid, id)
                redisLib:sendDelete(key)
                redisLib:sendzRem(self.playerDataCache:getClearRedisKey(), key)
            end
        end
    end
    if uid then
        -- 玩家数据落地
        f(uid, gRedisType.player)
        -- 迁服
        if newKid and newKid > 0 then
            -- 邮件数据落地, 目前邮件放game服, 最好是放global服
            self:saveMail()
            for i = 1, playerDataLib.serviceNum do
                if i ~= self.idx then
                    skynet.call(playerDataLib:address(self.kid, i), "lua", "saveMail")
                end
            end
            -- 设置玩家当前所在王国KID
            playerDataLib:setKidOfUid(uid, newKid, 1)
        end
    end
    gLog.i("playerDataCenter:logout end=", uid, newKid)
    --gLog.dump(self, "playerDataCenter:logout self=")
    return true
end

-- 邮件数据落地
function playerDataCenter:saveMail()
    local list = self.dbTask:keys("mail")
    if #list > 0 then
        if #list > 1000 then -- 数量太多, 预警一下, 是时候把邮件放global服了
            gLog.e("playerDataCenter:saveMail mail too much", #list)
        end
        for _,v in ipairs(list) do
            local arr = svrFunc.split(v, "-")
            if arr[1] and arr[2] then
                local sq = self:getSq(arr[1], arr[2])
                sq(function()
                    self:dealRedisTask(arr[1], arr[2])
                    self:dealDbTask(arr[1], arr[2])
                end)
                self:delSq(v)
            end
        end
    end
end

-- 订阅redis玩家王国KID变更频道
function playerDataCenter:subscribe()
    if self.idx == 1 then
        local publicRedisLib = require("publicRedisLib")
        local ok = publicRedisLib:subscribe(dbconf.publicRedis, playerDataLib.channel)
        gLog.i("playerDataCenter:subscribe=", ok)
        if ok then
            local f = function()
                local msg, channel = publicRedisLib:message(playerDataLib.channel)
                -- gLog.d("playerDataCenter:subscribe receive", channel, msg, table2string(json.decode(msg)))
                msg = json.decode(msg)
                if type(msg) == "table" then
                    local uid, kid = tonumber(msg.uid), tonumber(msg.kid)
                    if uid and kid then
                        gLog.i("playerDataCenter:subscribe setKidOfUid=", uid, kid)
                        skynet.send(playerDataLib:address(self.kid, uid), "lua", "setKidOfUid", uid, nil) -- 清理
                    end
                end
            end
            skynet.fork(function(f)
                while true do
                    f()
                    if self.stoped then
                        break
                    end
                end
            end, f)
        else
            gLog.e("playerDataCenter:subscribe error, ok=", ok)
        end
    end
end

-- 获取串行队列
function playerDataCenter:getSq(id, module)
    local key = self:getTaskKey(id, module)
    if not self.sq[key] then
        self.sq[key] = skynetQueue()
    end
    self.playerDataCache:addZsetSq(key)
    return self.sq[key]
end

-- 删除串行队列
function playerDataCenter:delSq(key)
    if self.sq[key] then
        self.sq[key] = nil
    end
end

-- 分发服务端调用（此处无xpcall防止导致数据覆盖）
function playerDataCenter:dispatchCmd(session, source, cmd, ...)
    -- gLog.d("playerDataCenter:dispatchCmd", session, source, cmd, ...)
    local f = self[cmd]
    if f then
        if 0 == session then
            f(self, ...)
        else
            self:ret(xpcall(f, svrFunc.exception, self, ...))
        end
    else
        if 0 ~= session then
            self:ret()
        end
        gLog.e("serviceCenterBase:dispatchCmd error: cmd not found:", cmd, ...)
    end
end

-- 返回数据
function playerDataCenter:ret(ok, ...)
    -- assert(ok == true)
    if ok then
        skynet.ret(skynet.pack(...))
    else
        skynet.ret(skynet.pack(self.errd))
    end
end

return playerDataCenter
