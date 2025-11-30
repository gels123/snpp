--[[
	数据中心接口
]]
local skynet = require("skynet")
local json = require("json")
local hash = require ("chash")
local dbconf = require("dbconf")
local svrAddrMgr = require("svrAddrMgr")
local publicRedisLib = require("publicRedisLib")
local playerDataLib = class("playerDataLib")

-- 服务数量
playerDataLib.serviceNum = 8
-- 玩家UID关联王国KID的redis哈希
playerDataLib.keyKidOfUid = "game-kidofuid"
playerDataLib.kidOfUid = {}
-- 联盟AID关联王国KID的redis哈希
playerDataLib.keyKidOfAid = "game-kidofaid"
playerDataLib.kidOfAid = {}
-- 王国KID变更频道
playerDataLib.channel = "channel_kid"
-- 调用异常需返回特殊标识, 注意数据重置风险
playerDataLib.errd = "__errd__"
--
local tonumber, tostring, assert, select, string, gLog = tonumber, tostring, assert, select, string, gLog

-- 获取地址
function playerDataLib:address(curKid, module, id)
    id = hash.fnv_hash((module or "")..tostring(id))
    id = id % playerDataLib.serviceNum + 1
    return svrAddrMgr.getSvr(svrAddrMgr.dataCenterSvr, curKid, id)
end

-- 返回(若第1个参数="__errd", 数据中心已异常, 此处再抛异常)
function playerDataLib:ret(...)
    assert(select(1, ...) ~= playerDataLib.errd)
    return ...
end

--[[
    查询
    @curKid         [必填]传本王国ID
    @id             [必填]数据ID
    @module         [必填]数据名
    @custom          [选填]根据多个条件查询
    @force          [选填]查询跨服数据时, 是否强制查询
    示例:
        1. playerDataLib:query(1, 1201, "lordinfo")
        2. playerDataLib:query(1, 1201, "lordinfo", {"_id":1001})
]]
function playerDataLib:query(curKid, id, module, custom, force)
    return self:ret(skynet.call(self:address(curKid, module, id), "lua", "query", id, module, custom, force))
end

--[[
    更新
    @curKid         [必填]传本王国ID
    @id             [必填]数据ID
    @module         [必填]数据名
    @data           [必填]数据
    示例:
        1. playerDataLib:update(1, 1201, "lordinfo", {_id = 1201, name = "ABC"})
]]
function playerDataLib:update(curKid, id, module, data)
	return self:ret(skynet.call(self:address(curKid, module, id), "lua", "update", id, module, data))
end

--[[
    更新(异步)
    @curKid         [必填]传本王国ID
    @id             [必填]数据ID
    @module         [必填]数据名
    @data           [必填]数据
    示例:
        1. playerDataLib:sendUpdate(1, 1201, "lordinfo", {_id = 1201, name = "ABC"})
]]
function playerDataLib:sendUpdate(curKid, id, module, data)
	skynet.send(self:address(curKid, module, id), "lua", "sendUpdate", id, module, data)
end

--[[
    删除
    @id             [必填]数据ID
    @module         [必填]数据名
    @custom         [选填]根据多个条件删除
    示例:
        1. playerDataLib:delete(1, 1201, "lordinfo")
        2. playerDataLib:delete(1, 1201, "lordinfo", {id = 1201, })
]]
function playerDataLib:delete(curKid, id, module, custom)
	return self:ret(skynet.call(self:address(curKid, module, id), "lua", "delete", id, module, custom))
end

--[[
    删除(异步)
    @id             [必填]数据ID
    @module         [必填]数据名
    @custom         [选填]根据多个条件删除
    示例:
        1. playerDataLib:sendDelete(1, 1201, "lordinfo")
        2. playerDataLib:sendDelete(1, 1201, "lordinfo", {id = 1201, })
]]
function playerDataLib:sendDelete(curKid, id, module, custom)
	return skynet.send(self:address(curKid, module, id), "lua", "sendDelete", id, module, custom)
end

-- 执行sql(非安全)
function playerDataLib:executeSql(curKid, id, sql, ...)
    return self:ret(skynet.call(self:address(curKid, nil, id), "lua", "executeSql", sql, ...))
end

-- 玩家/联盟彻底离线(数据落地)
-- @newKid 迁服时传, 同时删除本地redis数据
function playerDataLib:logout(curKid, uid, newKid)
    gLog.i("playerDataLib:logout", curKid, uid, newKid)
    return self:ret(skynet.call(self:address(curKid, nil, uid), "lua", "logout", uid, newKid))
end

--[[
    获取玩家当前所在王国KID
    注：非数据中心服调用时, cache可能是错的, 转发数据中心服处理
       共享redis非性能热点, qps能达20000+/s, 且有内存缓存
]]
function playerDataLib:getKidOfUid(curKid, uid)
    --gLog.d("playerDataLib:getKidOfUid=", curKid, uid)
    uid = tonumber(uid)
    if uid and uid > 0 then
        local addr = self:address(curKid, nil, uid)
        if skynet.self() ~= addr then
            return skynet.call(addr, "lua", "getKidOfUid", uid)
        end
        local kid = self.kidOfUid[uid]
        if not kid then
            kid = tonumber(publicRedisLib:hGet(self.keyKidOfUid, tostring(uid)))
            --gLog.d("playerDataLib:getKidOfUid hGet=", uid, kid)
            if not kid then
                local playerDataCenter = require("playerDataCenter").shareInstance()
                if dbconf.dbtype == "mongodb" then
                    local ret = playerDataCenter:executeSql("find", uid, "account")
                    if ret and not ret.err and ret[1] then
                        kid = tonumber(ret[1].kid)
                    end
                elseif dbconf.dbtype == "mysql" then
                    local sql = playerDataCenter.dbWrap:getQuerySql(uid, "account")
                    local ret = playerDataCenter:executeSql(sql)
                    if ret and not ret.err and ret[1] then
                        kid = tonumber(ret[1].kid)
                    end
                else
                    assert(false, "dbtype error"..tostring(dbconf.dbtype))
                end
                if kid and kid > 0 then
                    self.kidOfUid[uid] = kid
                    publicRedisLib:hSet(self.keyKidOfUid, tostring(uid), kid)
                else
                    gLog.e("playerDataLib:getKidOfUid error, curKid=", curKid, "uid=", uid)
                end
            else
                self.kidOfUid[uid] = kid
            end
        end
        return kid
    end
end

-- 设置玩家当前所在王国KID
function playerDataLib:setKidOfUid(uid, kid, flag)
    gLog.d("playerDataLib:setKidOfUid", uid, kid, flag)
    if uid and uid > 0 then
        if kid and kid > 0 then
            if self.kidOfUid[uid] then
                self.kidOfUid[uid] = kid
            end
            -- 0=更新redis并发布到频道
            if flag then
                publicRedisLib:hSet(self.keyKidOfUid, tostring(uid), kid)
                publicRedisLib:publish(self.channel, json.encode({uid = uid, kid = kid}))
            end
            -- 1=更新mysql
            if flag == 1 then
                local sql = string.format("update account set kid = '%s' where uid = '%s'", kid, uid)
                require("playerDataCenter"):shareInstance():executeSqlSafe(sql, uid, "account")
            end
        else
            self.kidOfUid[uid] = nil
        end
    end
end

--[[
    [废弃]获取联盟当前所在王国KID
    注：非数据中心调用, game服动态扩容数据迁服时cache可能是错的, 需要传flag=true
]]
function playerDataLib:getKidOfAid(curKid, aid, flag)
    -- gLog.d("playerDataLib:getKidOfAid", curKid, aid, flag)
    aid = tonumber(aid)
    if aid and aid > 0 then
        local addr = self:address(curKid, aid)
        if flag or skynet.self() ~= addr then
            return skynet.call(addr, "lua", "getKidOfAid", aid)
        end
        local kid = self.kidOfAid[aid]
        if not kid then
            kid = tonumber(publicRedisLib:hGet(self.keyKidOfAid, tostring(aid)))
            --gLog.d("playerDataLib:getKidOfAid hGet=", aid, kid)
            if not kid then
                local sql = string.format("select kid from alliance where id = %d", aid)
                local ret = skynet.call(addr, "lua", "executeSql", sql)
                if ret and not ret.err and ret[1] and ret[1].kid then
                    kid = tonumber(ret[1].kid)
                    if kid then
                        self.kidOfAid[aid] = kid
                        publicRedisLib:hSet(self.keyKidOfAid, tostring(aid), kid)
                    else
                        gLog.e("playerDataLib:getKidOfAid error, curKid=", curKid, "aid=", aid, "sql=", sql)
                    end
                end
            else
                self.kidOfAid[aid] = kid
            end
        end
        return kid
    end
end

-- [废弃]设置联盟当前所在王国KID
function playerDataLib:setKidOfAid(aid, kid, flag)
    -- gLog.d("playerDataLib:setKidOfAid", aid, kid, flag)
    if aid and aid > 0 then
        if kid and kid > 0 then
            if self.kidOfAid[aid] ~= kid then
                self.kidOfAid[aid] = kid
                -- 更新redis
                publicRedisLib:hSet(self.keyKidOfAid, tostring(aid), kid)
                -- 更新mysql
                if flag then
                    local sql = string.format("update alliance set kid = '%s' where id = '%s'", kid, aid)
                    require("playerDataCenter"):shareInstance():executeSqlSafe(sql, aid, "alliance")
                end
            end
        else
            self.kidOfAid[aid] = nil
        end
    end
end

return playerDataLib
