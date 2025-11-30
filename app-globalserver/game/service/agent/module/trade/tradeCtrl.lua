--[[
	拍卖行模块
]]
local skynet = require("skynet")
local agentCenter = require("agentCenter"):shareInstance()
local snowflake = require("snowflake")
local commonLib = require("commonLib")
local baseCtrl = require("baseCtrl")
local tradeCtrl = class("tradeCtrl", baseCtrl)

-- 构造
function tradeCtrl:ctor(uid)
    self.super.ctor(self, uid)
    self.module = "tradeinfo" -- 数据表名
end

-- 初始化
function tradeCtrl:init()
    if self.bInit then
        return
    end
    -- 设置已初始化
    self.bInit = true
    self.data = self:queryDB()
    if "table" ~= type(self.data) then
        self.data = self:defaultData()
        self:updateDB()
    end
    --gLog.dump(self.data, "tradeCtrl:init self.data=")
end

-- 默认数据
function tradeCtrl:defaultData()
    return {
        goods = {},          -- 已上架的拍卖商品(备份)
    }
end

-- 查询拍卖物
function tradeCtrl:getGoods()
    return self.data.goods or {}
end

-- 添加拍卖物
function tradeCtrl:addGoods(id, count, gold)
    -- 参数校验
    if not id or not count or not gold or gold <= 0 then
        gLog.d("tradeCtrl:addGoods error1", self.uid, id, count)
        return false, gErrDef.Err_ILLEGAL_PARAMS
    end
    -- 扣除拍卖道具
    local kid = require("playerDataLib"):getKidOfUid(agentCenter.kid, self.uid)
    local ok = require("agentLibGm"):callModule(kid, self.uid, gModuleDef.backpackModule, "deductItem", id, count)
    if ok ~= true then
        gLog.w("tradeCtrl:addGoods error2", self.uid, id, count)
        return false, gErrDef.Err_ILLEGAL_PARAMS
    end
    -- 添加拍卖物
    local good = {
        idx = tostring(snowflake.nextid()),
        uid = self.uid,
        type = 0,
        id = id,
        count = count,
        gold = gold,
        time = svrFunc.skynetTime() + 864000,
    }
    local pok, ok = xpcall(function()
        return commonLib:call(good.idx, "addGoods", good)
    end, svrFunc.exception)
    if not pok or not ok then
        gLog.w("tradeCtrl:addGoods error3", self.uid, id, count, pok, ok)
        -- 返还已扣除拍卖道具
        pcall(function()
            kid = require("playerDataLib"):getKidOfUid(agentCenter.kid, self.uid)
            local ok = require("agentLibGm"):callModule(kid, self.uid, gModuleDef.backpackModule, "addItem", id, count)
            if ok ~= true then
                gLog.w("tradeCtrl:addGoods return items fail", self.uid, good.id, good.count)
            end
        end)
        return false, gErrDef.Err_SERVICE_EXCEPTION
    end
    gLog.i("tradeCtrl:addGoods", self.uid, id, count, ok)
    self.data.goods[good.idx] = good
    self:updateDB()

    return true, good
end

-- 撤回拍卖物
function tradeCtrl:remGoods(idx)
    if not idx then
        gLog.d("tradeCtrl:remGoods error", self.uid, idx)
        return false, gErrDef.Err_ILLEGAL_PARAMS
    end
    local good = idx and self.data.goods and self.data.goods[idx]
    gLog.i("tradeCtrl:remGoods", self.uid, idx, good and good.id, good and good.count)
    if good then
        self.data.goods[idx] = nil
        self:updateDB()
    end
    -- 撤回拍卖物
    local pok, ok, err = xpcall(function()
        return commonLib:call(good.idx, "remGoods", self.uid, good.type, good.idx)
    end, svrFunc.exception)
    if not pok or not ok then
        gLog.w("tradeCtrl:remGoods", self.uid, idx, good.id, good.count, err)
        return false, err or gErrDef.Err_SERVICE_EXCEPTION
    end
    -- 返回背包
    local kid = require("playerDataLib"):getKidOfUid(agentCenter.kid, self.uid)
    local ok = require("agentLibGm"):callModule(kid, self.uid, gModuleDef.backpackModule, "addItem", good.id, good.count)
    if ok ~= true then
        gLog.w("tradeCtrl:remGoods addItem fail", self.uid, good.id, good.count)
    end
    return true
end

-- 卖出拍卖物
function tradeCtrl:sellGoods(idx, gold)
    if not idx then
        gLog.w("tradeCtrl:sellGoods", self.uid, idx, gold)
        return false
    end
    local good = self.data.goods[idx]
    if good then
        self.data.goods[idx] = nil
        self:updateDB()
    end
    gLog.i("tradeCtrl:sellGoods", self.uid, idx, good and good.id, good and good.count, good and good.gold)
    if good then
        pcall(function()
            local kid = require("playerDataLib"):getKidOfUid(agentCenter.kid, self.uid)
            local ok = require("agentLibGm"):callModule(kid, self.uid, gModuleDef.backpackModule, "addItem", gItemIdCommon.GOLD, good.gold)
            if ok ~= true then
                gLog.w("tradeCtrl:sellGoods addItem fail", self.uid, good.id, good.count)
            end
        end)
    end
    return true
end

return tradeCtrl
