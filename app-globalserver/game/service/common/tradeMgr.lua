--[[
    交易所管理器
]]
local skynet = require("skynet")
local commonLib = require("commonLib")
local redisLib = require("publicRedisLib")
local playerDataLib = require("playerDataLib")
local commonCenter = require("commonCenter"):shareInstance()
local tradeMgr = class("tradeMgr")

-- 构造
function tradeMgr:ctor()
    self.module = "tradegoods"	-- 数据表名
    self.data = nil		        -- 数据
end

-- 数据id
function tradeMgr:dataId()
    return commonCenter.kid * 100 + commonCenter.idx
end

-- redis键
function tradeMgr:redisKey(type)
    return string.format("game_trade_%s", type)
end

-- 默认数据
function tradeMgr:defaultData()
    return {
        round = 0,      -- 轮次
        startTime = 0,  -- 开始时间
        endTime = 0,    -- 结束时间
        goods = {},     -- 拍卖物
    }
end

-- 初始化
function tradeMgr:init()
    self.data = self:queryDB()
    if "table" ~= type(self.data) then
        self.data = self:defaultData()
        self:updateDB()
    end
    -- 维护拍卖顺序列表
    if self.data.goods then
        for type,v in pairs(self.data.goods) do
            for idx,good in pairs(v) do
                redisLib:sendzAdd(self:redisKey(type), good.time, idx)
            end
        end
    end
end

-- 查询数据库
function tradeMgr:queryDB()
    assert(self.module, "tradeMgr:queryDB error!")
    return playerDataLib:query(commonCenter.kid, self:dataId(), self.module)
end

-- 更新数据库
function tradeMgr:updateDB()
    local data = self:getDataDB()
    assert(self.module and data, "tradeMgr:updateDB error!")
    playerDataLib:sendUpdate(commonCenter.kid, self:dataId(), self.module, data)
end

-- 获取存库数据
function tradeMgr:getDataDB()
    return self.data
end

-- 添加拍卖物
function tradeMgr:addGoods(good)
    gLog.d("tradeMgr:addGoods", good.uid, good.type, good.id, good.count)
    --
    if type(good) ~= "table" or not good.idx or not good.uid or not good.type or not good.id or not good.count or not good.gold or not good.time then
        gLog.w("tradeMgr:addGoods error", table2string(good))
        return false, gErrDef.Err_ILLEGAL_PARAMS
    end
    --
    gLog.i("tradeMgr:addGoods", good.uid, good.type, good.id, good.count, good.idx)
    if not self.data.goods[good.type] then
        self.data.goods[good.type] = {}
    end
    self.data.goods[good.type][good.idx] = good
    self:updateDB()
    -- 维护拍卖顺序列表
    redisLib:sendzAdd(self:redisKey(good.type), good.time, good.idx)

    return true
end

-- 撤回拍卖物
function tradeMgr:remGoods(uid, type, idx)
    if not uid or not type or not idx then
        gLog.w("tradeMgr:remGoods", uid, type, idx)
        return false, gErrDef.Err_ILLEGAL_PARAMS
    end
    if self.data.goods[type] and self.data.goods[type][idx] and self.data.goods[type][idx].uid == uid then
        gLog.i("tradeMgr:remGoods", uid, type, idx)
        self.data.goods[type][idx] = nil
        self:updateDB()
        -- 维护拍卖顺序列表
        redisLib:sendzRem(self:redisKey(type), idx)
        return true
    end
    return false, gErrDef.Err_TRADE_GOODS_NOT_EXIST
end

-- 购买拍卖物
function tradeMgr:buyGood(uid, type, idx, id, gold)
    --
    if not uid or not type or not idx or not id or not gold then
        gLog.w("tradeMgr:buyGood fail1", uid, type, idx, id, gold)
        return false, gErrDef.Err_ILLEGAL_PARAMS
    end
    --
    local good = self.data.goods[type] and self.data.goods[type][idx]
    if not good or good.uid ~= uid or good.id ~= id or good.gold ~= gold then
        gLog.w("tradeMgr:buyGood fail2", uid, type, idx, id, gold)
        return false, gErrDef.Err_TRADE_BUY_INVALID
    end
    --
    self.data.goods[type][idx] = nil
    self:updateDB()
    -- 维护拍卖顺序列表
    redisLib:sendzRem(self:redisKey(type), idx)
    return true, good
end

-- 获取拍卖物
function tradeMgr:getGoods(type, idx1, idx2)
    local ret = {}
    if idx2 >= idx1 then
        local ranges = redisLib:zRevRange(self:redisKey(type), idx1, idx2)
        --gLog.dump(ranges, "tradeMgr:getGoods ranges=")
        if #ranges > 0 then
            for k,idx in pairs(ranges) do
                if self.data.goods[type] and self.data.goods[type][idx] then
                    table.insert(ret, self.data.goods[type][idx])
                else
                    local ok,good = xpcall(function()
                        return commonLib:call(idx, "getGood", type, idx)
                    end, svrFunc.exception)
                    if ok and good then
                        table.insert(ret, good)
                    end
                end
            end
        end
    end
    gLog.dump(ret, "tradeMgr:getGoods ret=")
    return ret
end

-- 获取单个拍卖物
function tradeMgr:getGood(type, idx)
    --gLog.d("tradeMgr:getGood", commonCenter.idx, type, idx)
    return self.data.goods[type] and self.data.goods[type][idx]
end

return tradeMgr
