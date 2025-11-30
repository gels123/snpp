local skynet = require("skynet")
local json = require("json")
local svrFunc = require("svrFunc")
local svrAddrMgr = require("svrAddrMgr")
local playerDataConfig = require("playerDataConfig")
local dbWrap = require("dbWrap.dbWrap")
local mongodbWrap = class("mongodbWrap", dbWrap)

local gLog, string, table, type, next, pairs, xpcall = gLog, string, table, type, next, pairs, xpcall

-- override
function mongodbWrap:getAddress()
    return svrAddrMgr.getSvr(svrAddrMgr.gameDBSvr)
end

-- override
function mongodbWrap:query(kid, id, module, custom)
    local setting = playerDataConfig.moduleSettings[module]
    if setting.columns then
        local ok, ret = xpcall(function ()
            local address = self:getAddress()
            return skynet.call(address, "lua", "findOne", id, module, custom)
        end, svrFunc.exception)
        if not ok then -- mongodb宕机, 中断执行
            error(string.format("mongodbWrap:query error1: kid=%s, id=%s, module=%s", kid, id, module))
        end
        if type(ret) == "table" then
            if ret.err then
                -- 查询异常, 中断业务
                error(string.format("mongodbWrap:query error2: kid=%s, id=%s, module=%s ret=%s", kid, id, module, json.encode(ret)))
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

-- 查询结果解包
function mongodbWrap:queryResultPack(ret, module)
    -- gLog.dump(ret, "mongodbWrap:queryResultPack module="..tostring(module), 10)
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
function mongodbWrap:update(kid, id, module, data)
    local setting = playerDataConfig.moduleSettings[module]
    if setting.columns then
        -- 更新缓存
        self.playerDataCenter.playerDataCache:update(kid, id, module, data, true)
        -- 更新mongodb
        if kid == self.playerDataCenter.kid then
            -- 需提前处理更新任务
            xpcall(function ()
                self.playerDataCenter:dealDbTask(id, module)
            end, svrFunc.exception)
            -- 执行更新(安全的)
            local ok, ret = self:executeSqlSafe("safe_update", id, module, data)
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
function mongodbWrap:sendUpdate(kid, id, module, data)
    local setting = playerDataConfig.moduleSettings[module]
    if setting.columns then
        -- 更新缓存
        self.playerDataCenter.playerDataCache:update(kid, id, module, data, true)
        -- 更新mongodb
        if kid == self.playerDataCenter.kid then
            -- 添加到mongodb任务队列
            local taskKey = self.playerDataCenter:getTaskKey(id, module)
            self.playerDataCenter.dbTask:push(taskKey, {cmd = "safe_update", id = id, module = module, data = data, time = skynet.time(),})
        end
    -- 无需落库
    else
        -- 更新缓存
        self.playerDataCenter.playerDataCache:update(kid, id, module, data, true)
    end
end

-- override
function mongodbWrap:delete(kid, id, module, custom)
    local setting = playerDataConfig.moduleSettings[module]
    if setting.columns then
        -- 删除缓存
        self.playerDataCenter.playerDataCache:delete(kid, id, module, custom, true)
        -- 更新mongodb
        if kid == self.playerDataCenter.kid then
            xpcall(function ()
                self.playerDataCenter:dealDbTask(id, module)
            end, svrFunc.exception)
            local ok, ret = self:executeSqlSafe("delete", id, module, custom)
            if not ok or not ret or ret.err then
                return false
            end
        end
    -- 无需落库mongodb
    else
        -- 删除缓存
        self.playerDataCenter.playerDataCache:delete(kid, id, module, custom, true)
    end
    return true
end

-- override
function mongodbWrap:sendDelete(kid, id, module, custom)
    local setting = playerDataConfig.moduleSettings[module]
    if setting.columns then
        -- 删除缓存
        self.playerDataCenter.playerDataCache:delete(kid, id, module, custom, true)
        -- 更新mongodb
        if kid == self.playerDataCenter.kid then
            -- 添加mongodb任务队列
            local taskKey = self.playerDataCenter:getTaskKey(id, module)
            self.playerDataCenter.dbTask:push(taskKey, {cmd = "delete", id = id, module = module, custom = custom, time = skynet.time(),})
        end
    -- 无需落库
    else
        -- 删除缓存
        self.playerDataCenter.playerDataCache:delete(kid, id, module, custom, true)
    end
    return true
end

function mongodbWrap:executeSql(cmd, id, module, data, custom)
    gLog.d("mongodbWrap:executeSql cmd=", cmd, id, module, data, custom)
    local address = self:getAddress()
    return skynet.call(address, "lua", cmd, id, module, data, custom)
end

-- 执行sql(安全的)
-- @id & module 数据ID&数据数据名, 两者都传时, 可以在内存耗尽crash前异常处理
function mongodbWrap:executeSqlSafe(cmd, id, module, data, custom)
    gLog.d("mongodbWrap:executeSqlSafe cmd=", cmd, id, module, data, custom)
    local ok, ret = xpcall(function ()
        local address = self:getAddress()
        return skynet.call(address, "lua", cmd, id, module, data, custom)
    end, svrFunc.exception)
    if not ok or not ret then
        -- mongodb宕机, 写库异常时, 重新加到mongodb任务队列, 并开启mongodb断线重连
        -- if not ok then
            self.playerDataCenter.playerDataTimer:onDbReconnect()
            if id and module then
                if string.find(cmd, "insert") or string.find(cmd, "update") or string.find(cmd, "delete") then
                    local taskKey = self.playerDataCenter:getTaskKey(id, module)
                    self.playerDataCenter.dbTask:push(taskKey, {cmd = cmd, id = id, module = module, data = data, custom = custom, time = skynet.time(),})
                end
            end
        -- end
        error(string.format("mongodbWrap:executeSqlSafe sql=%s ok=%s ret=%s", cmd, ok, table2string(ret)))
    end
    return ok, ret
end

function mongodbWrap:isDbAlive()
    local address = self:getAddress()
    local ret = skynet.call(address, "lua", "keepalive")
    return ret
end

function mongodbWrap:onDbReconnect()
    local address = self:getAddress()
    local pok, ok = xpcall(function ()
        return skynet.call(address, "lua", "keepalive")
    end, svrFunc.exception)
    if not pok or not ok then
        pok, ok = xpcall(function ()
        skynet.call(svrAddrMgr.getSvr(svrAddrMgr.confDBSvr), "lua", "reconnect", self.confdb)
            return skynet.call(address, "lua", "reconnect", self.gamedb)
        end, svrFunc.exception)
        gLog.i("mongodbWrap:onDbReconnect gameDBSvr pok=", pok, "ok=", ok)
    end
    return pok, ok
end

return mongodbWrap