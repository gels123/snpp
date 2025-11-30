local skynet = require("skynet")
local json = require("json")
local svrFunc = require("svrFunc")
local svrAddrMgr = require("svrAddrMgr")
local playerDataConfig = require("playerDataConfig")
local dbWrap = require("dbWrap.dbWrap")
local mysqlWrap = class("mysqlWrap", dbWrap)

local gLog, string, table, type, next, pairs, xpcall = gLog, string, table, type, next, pairs, xpcall

-- override
function mysqlWrap:getAddress()
    return svrAddrMgr.getSvr(svrAddrMgr.gameDBSvr)
end

-- override
function mysqlWrap:query(kid, id, module, custom)
    -- 查询mysql
    local sql = self:getQuerySql(id, module, custom)
    gLog.d("mysqlWrap:query sql=", sql)
    if sql then
        local ok, ret = xpcall(function ()
            return skynet.call(self:getAddress(), "lua", "execute", sql)
        end, svrFunc.exception)
        if not ok then -- mysql宕机, 中断执行
            error(string.format("mysqlWrap:query error1: kid=%s, id=%s, module=%s", kid, id, module))
        end
        if type(ret) == "table" then
            if ret.err then
                -- sql异常, 中断业务
                error(string.format("mysqlWrap:query error2: kid=%s, id=%s, module=%s ret=%s", kid, id, module, json.encode(ret)))
            else
                -- 查询结果包装
                local data = self:queryResultPack(ret, module)
                if data ~= nil then
                    -- 更新缓存
                    self.playerDataCenter.playerDataCache:update(kid, id, module, data, false)
                end
                return data
            end
        end
    end
end

-- 获取查询sql
function mysqlWrap:getQuerySql(id, module, custom)
    local setting = playerDataConfig.moduleSettings[module]
    if not setting.columns then
        return
    end
    if custom and type(custom) == "table" and next(custom) then
        -- 复杂查询, 根据传入字段, 查询所有dataColumns字段
        local where = {}
        for k,v in pairs(custom) do
            table.insert(where, string.format("%s = '%s'", k, v))
        end
        return string.format("SELECT %s FROM %s WHERE %s;", table.concat(setting.dataColumns, " , "), setting.table, table.concat(where, " and "))
    else
        -- 简单查询, 根据第一个keyColumns字段, 查询所有dataColumns字段
        return string.format("SELECT %s FROM %s WHERE %s = '%s';", table.concat(setting.dataColumns, " , "), setting.table, setting.keyColumns[1], id)
    end
end

-- 查询结果解包
function mysqlWrap:queryResultPack(ret, module)
    -- gLog.dump(ret, "mysqlWrap:queryResultPack module="..tostring(module), 10)
    if ret and #ret >= 1 then -- 查询结果必须至少得有1条
        for _,record in pairs(ret) do
            for k,v in pairs(record) do
                if type(v) == "string" then
                    record[k] = json.decode(v) or v
                end
            end
        end
        local setting = playerDataConfig.moduleSettings[module]
        if #setting.dataColumns == 1 and #ret == 1 then
            if table.nums(ret[1]) == 1 then
                local _,v = next(ret[1])
                return v
            else
                return ret[1]
            end
        end
        return ret
    end
    return nil
end

-- override
function mysqlWrap:update(kid, id, module, data)
    -- 更新sql
    local sql = self:getUpdateSql(id, module, data)
    --gLog.d("mysqlWrap:update sql=", sql)
    -- 需要落库
    if sql then
        -- 更新缓存
        self.playerDataCenter.playerDataCache:update(kid, id, module, data, true)
        -- 更新mysql
        if kid == self.playerDataCenter.kid then
            -- 需提前处理更新任务
            xpcall(function ()
                self.playerDataCenter:dealDbTask(id, module)
            end, svrFunc.exception)
            -- 执行sql(安全的)
            local ok, ret = self:executeSqlSafe(sql, id, module)
            if not ok or not ret or ret.err then
                return false
            end
        end
    -- 无需落库
    else
        -- 更新缓存
        self.playerDataCenter.playerDataCache:update(kid, id, module, data, true)
    end
    return true
end

-- override
function mysqlWrap:sendUpdate(kid, id, module, data)
    -- 更新sql
    local sql = self:getUpdateSql(id, module, data)
    --gLog.d("mysqlWrap:sendUpdate sql=", sql)
    -- 需要落库
    if sql then
        -- 更新缓存
        self.playerDataCenter.playerDataCache:update(kid, id, module, data, true)
        -- 更新mysql
        if kid == self.playerDataCenter.kid then
            -- 添加到mysql任务队列
            local taskKey = self.playerDataCenter:getTaskKey(id, module)
            self.playerDataCenter.dbTask:push(taskKey, {cmd = "update", id = id, module = module, sql = sql, time = skynet.time(),})
        end
    -- 无需落库
    else
        -- 更新缓存
        self.playerDataCenter.playerDataCache:update(kid, id, module, data, true)
    end
end

-- 获取更新sql
function mysqlWrap:getUpdateSql(id, module, data)
    local setting = playerDataConfig.moduleSettings[module]
    if not setting.columns then
        return
    end
    -- 简单更新, 根据第一个 keyColumns 字段(通常为id字段), 更新第一个dataColumns字段(通常为data字段)
    if type(data) == "table" then
        data = svrFunc.escape(json.encode(data))
    end
    return string.format("INSERT INTO %s(%s, %s) VALUES ('%s', '%s') ON DUPLICATE KEY UPDATE %s='%s';", setting.table, setting.keyColumns[1], setting.dataColumns[1], id, data, setting.dataColumns[1], data)
end

-- override
function mysqlWrap:delete(kid, id, module, custom)
    -- 删除sql
    local sql = self:getDeleteSql(id, module, custom)
    --gLog.d("mysqlWrap:delete sql=", sql)
    -- 需要落库
    if sql then
        -- 删除缓存
        self.playerDataCenter.playerDataCache:delete(kid, id, module, custom, true)
        -- 更新mysql
        if kid == self.playerDataCenter.kid then
            xpcall(function ()
                self.playerDataCenter:dealDbTask(id, module)
            end, svrFunc.exception)
            local ok, ret = self:executeSqlSafe(sql, id, module)
            if not ok or not ret or ret.err then
                return false
            end
        end
    -- 无需落库mysql
    else
        -- 删除缓存
        self.playerDataCenter.playerDataCache:delete(kid, id, module, custom, true)
    end
    return true
end

-- override
function mysqlWrap:sendDelete(kid, id, module, custom)
    -- 删除sql
    local sql = self:getDeleteSql(id, module, custom)
    --gLog.d("mysqlWrap:sendDelete sql=", sql)
    -- 需要落库
    if sql then
        -- 删除缓存
        self.playerDataCenter.playerDataCache:delete(kid, id, module, custom, true)
        -- 更新mysql
        if kid == self.playerDataCenter.kid then
            -- 添加mysql任务队列
            local taskKey = self.playerDataCenter:getTaskKey(id, module)
            self.playerDataCenter.dbTask:push(taskKey, {cmd = "delete", id = id, module = module, sql = sql, time = skynet.time(),})
        end
    -- 无需落库
    else
        -- 删除缓存
        self.playerDataCenter.playerDataCache:delete(kid, id, module, custom, true)
    end
    return true
end

-- 获取删除sql
function mysqlWrap:getDeleteSql(id, module, custom)
    local setting = playerDataConfig.moduleSettings[module]
    if custom and type(custom) == "table" and next(custom) then
        -- 复杂更新, 根据条件, 查询所有dataColumns字段
        local whereList = {}
        for _,v in pairs(setting.columns) do
            if custom[v] then
                table.insert(whereList, string.format("%s = '%s'", v, custom[v]))
            end
        end
        return string.format("DELETE FROM %s WHERE %s;", setting.table, table.concat(whereList, " and "))
    else
        -- 简单删除, 根据第一个keyColumns字段删除
        return string.format("DELETE FROM %s WHERE %s = '%s';", setting.table, setting.keyColumns[1], id)
    end
end

function mysqlWrap:executeSql(sql)
    assert(type(sql) == "string")
    gLog.d("mysqlWrap:executeSql sql=", sql)
    return skynet.call(self:getAddress(), "lua", "execute", sql)
end

-- 执行sql(安全的)
-- @id & module 数据ID&数据数据名, 两者都传时, 可以在内存耗尽crash前异常处理
function mysqlWrap:executeSqlSafe(sql, id, module)
    assert(type(sql) == "string")
    gLog.d("mysqlWrap:executeSqlSafe sql=", sql, id, module)
    local ok, ret = xpcall(function ()
        return skynet.call(self:getAddress(), "lua", "execute", sql)
    end, svrFunc.exception)
    if not ok or not ret or ret.err then
        -- mysql宕机, 写库异常时, 重新加到mysql任务队列, 并开启mysql断线重连
        -- if not ok then
            self.playerDataCenter.playerDataTimer:onDbReconnect()
            if id and module then
                local sql2 = string.lower(sql)
                if string.find(sql2, "insert") or string.find(sql2, "update") or string.find(sql2, "delete") then
                    local taskKey = self.playerDataCenter:getTaskKey(id, module)
                    self.playerDataCenter.dbTask:push(taskKey, {sql = sql, id = id, module = module, time = skynet.time(),})
                end
            end
        -- end
        error(string.format("mysqlWrap:executeSqlSafe sql=%s ok=%s ret=%s", sql, ok, table2string(ret)))
    end
    return ok, ret
end

function mysqlWrap:isDbAlive()
    local ret = skynet.call(self:getAddress(), "lua", "keepalive")
    return ret
end

function mysqlWrap:onDbReconnect()
    local addr = self:getAddress()
    local pok, ok = xpcall(function ()
        return skynet.call(addr, "lua", "keepalive")
    end, svrFunc.exception)
    if not pok or not ok then
        pok, ok = xpcall(function ()
            skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "reconnect", self.confdb)
            return skynet.call(addr, "lua", "reconnect", self.gamedb)
        end, svrFunc.exception)
        gLog.i("mysqlWrap:onDbReconnect pok=", pok, "ok=", ok)
    end
    return pok, ok
end

return mysqlWrap