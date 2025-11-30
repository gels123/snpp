--[[
	数据中心接口(仅供login服务使用)
]]
local skynet = require("skynet")
local svrFunc = require("svrFunc")
local json = require("json")
local svrAddrMgr = require("svrAddrMgr")
local publicRedisLib = require("publicRedisLib")
local playerDataLib = class("playerDataLib")

-- 玩家UID关联王国KID的redis哈希
playerDataLib.keyKidOfUid = "game-kidofuid"
playerDataLib.kidOfUid = {}
-- 王国KID变更频道
playerDataLib.channel = "channel_kid"

--[[
    获取玩家当前所在王国KID
]]
function playerDataLib:getKidOfUid(uid)
    --gLog.d("playerDataLib:getKidOfUid=", uid)
    uid = tonumber(uid)
    if uid and uid > 0 then
        local kid = self.kidOfUid[uid]
        if not kid then
            kid = tonumber(publicRedisLib:hGet(self.keyKidOfUid, tostring(uid)))
            if not kid then
                
            end
        end
        if not kid then
            kid = tonumber(publicRedisLib:hGet(self.keyKidOfUid, tostring(uid)))
            --gLog.d("playerDataLib:getKidOfUid hGet=", uid, kid)
            if not kid then
                local playerDataCenter = require("playerDataCenter").shareInstance()
                if dbconf.dbtype == "mongodb" then
                    local address = svrAddrMgr.getSvr(svrAddrMgr.gameDBSvr)
                    local ret = skynet.call(address, "lua", "findOne", uid, "account")
                    --gLog.dump(ret, "playerDataLib:getKidOfUid ret=", 10)
                    if ret and not ret.err and ret[1] and ret[1].data then
                        local data = json.decode(ret[1].data)
                        kid = tonumber(data and data.kid)
                    end
                elseif dbconf.dbtype == "mysql" then
                    local address = svrAddrMgr.getSvr(svrAddrMgr.gameDBSvr)
                    local sql = string.format("select kid from account where _id = %d", uid)
                    local ret = skynet.call(address, "lua", "execute", sql)
                    --gLog.dump(ret, "playerDataLib:getKidOfUid ret=", 10)
                    if ret and not ret.err and ret[1] and ret[1].kid then
                        kid = tonumber(ret[1].kid)
                    end
                else
                    assert(false, "dbtype error"..tostring(dbconf.dbtype))
                end
                if kid and kid > 0 then
                    self.kidOfUid[uid] = kid
                    publicRedisLib:hSet(self.keyKidOfUid, tostring(uid), kid)
                else
                    gLog.e("playerDataLib:getKidOfUid error", "uid=", uid)
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
    uid, kid = tonumber(uid), tonumber(kid)
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
        else
            self.kidOfUid[uid] = nil
        end
    end
end

-- 订阅redis玩家王国KID变更频道
function playerDataLib:subscribe()
    --gLog.i("playerDataCenter:subscribe")
    local publicRedisLib = require("publicRedisLib")
    publicRedisLib:subscribe(dbconf.publicRedis, self.channel, function(data, channel)
        --gLog.d("playerDataCenter:subscribe receive", channel, data, table2string(json.decode(data)))
        data = json.decode(data)
        if type(data) == "table" then
            local uid, kid = tonumber(data.uid), tonumber(data.kid)
            if uid and kid then -- 玩家kid变更, 清理缓存
                gLog.i("playerDataLib:subscribe setKidOfUid=", uid, kid)
                self:setKidOfUid(uid, nil)
            end
        end
    end)
end

return playerDataLib