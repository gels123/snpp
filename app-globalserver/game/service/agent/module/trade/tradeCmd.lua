--[[
	拍卖行模块指令
]]
local skynet = require "skynet"
local commonLib = require "commonLib"
local playerDataLib = require "playerDataLib"
local agentCenter = require("agentCenter"):shareInstance()
local clientCmd = require "clientCmd"

-- 查询自己的拍卖物
function clientCmd.reqGoodsInfo(player, req)
    gLog.dump(req, "clientCmd.reqGoodsInfo uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        local tradeCtrl = player:getModule(gModuleDef.tradeModule)
        ret.goods = tradeCtrl:getGoods()
    until true

    ret.code = code
    return ret
end

-- 添加拍卖物
function clientCmd.reqAddGoods(player, req)
    gLog.dump(req, "clientCmd.reqAddGoods uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        local tradeCtrl = player:getModule(gModuleDef.tradeModule)
        local ok, code2 = tradeCtrl:addGoods(req.id, req.count, req.gold)
        if not ok then
            gLog.d("clientCmd.reqAddGoods err1", player:getUid())
            code = code2 or gErrDef.Err_SERVICE_EXCEPTION
            break
        end
        ret.good = code2
    until true

    ret.code = code
    return ret
end

-- 撤回拍卖物
function clientCmd.reqRemGoods(player, req)
    gLog.dump(req, "clientCmd.reqRemGoods uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        local tradeCtrl = player:getModule(gModuleDef.tradeModule)
        local ok, code2 = tradeCtrl:remGoods(req.idx)
        if not ok then
            code = code2 or gErrDef.Err_SERVICE_EXCEPTION
            break
        end
    until true

    ret.code = code
    return ret
end

-- 购买拍卖物
function clientCmd.reqBuyGoods(player, req)
    gLog.dump(req, "clientCmd.reqBuyGoods uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        --
        if not req.sellUid or req.sellUid == player:getUid() or not req.type or not req.idx or not req.id or not req.gold then
            gLog.d("clientCmd.reqBuyGoods err1", player:getUid())
            code = gErrDef.Err_ILLEGAL_PARAMS
            break
        end
        -- 扣除金币
        local kid = require("playerDataLib"):getKidOfUid(agentCenter.kid, player:getUid())
        local ok = require("agentLibGm"):callModule(kid, player:getUid(), gModuleDef.backpackModule, "deductItem", gItemIdCommon.GOLD, req.gold)
        if ok ~= true then
            gLog.d("clientCmd.reqBuyGoods err2", player:getUid(), req.idx, req.gold)
            code = gErrDef.Err_CURRENCY_INVALID
            break
        end
        -- 购买拍卖物
        local pok, ok, good = xpcall(function()
            return commonLib:call(req.idx, "buyGood", req.sellUid, req.type, req.idx, req.id, req.gold)
        end, svrFunc.exception)
        if not pok or not ok then
            gLog.w("tradeCtrl:reqBuyGoods err3", player:getUid(), req.type, req.idx, req.id)
            -- 返还金币
            pcall(function()
                kid = require("playerDataLib"):getKidOfUid(agentCenter.kid, player:getUid())
                local ok = require("agentLibGm"):callModule(kid, player:getUid(), gModuleDef.backpackModule, "addItem", gItemIdCommon.GOLD, req.gold)
                if ok ~= true then
                    gLog.w("tradeCtrl:reqBuyGoods return items fail", player:getUid(), good.idx, good.id, good.count)
                end
            end)
            return false, good or gErrDef.Err_SERVICE_EXCEPTION
        end
        -- 卖出拍卖物
        gLog.dump(good, "clientCmd.reqBuyGoods")
        local pok, ok = pcall(function()
            local kid2 = playerDataLib:getKidOfUid(agentCenter.kid, good.sellUid)
            gLog.i("clientCmd.reqBuyGoods sellGoods", good.sellUid, kid2, good.idx, good.id, good.count)
            return require("agentLib"):callModule(kid2, good.sellUid, gModuleDef.tradeModule, "sellGoods", good.idx, good.gold)
        end)
        if not pok or not ok then
            gLog.w("clientCmd.reqBuyGoods err4", player:getUid(), pok, ok, good.idx, good.id, good.gold)
        end
        -- 购买成功获得道具
        kid = require("playerDataLib"):getKidOfUid(agentCenter.kid, player:getUid())
        local ok = require("agentLibGm"):callModule(kid, player:getUid(), gModuleDef.backpackModule, "addItem", good.id, good.count)
        if ok ~= true then
            gLog.w("tradeCtrl:reqBuyGoods addItem fail", player:getUid(), good.idx, good.id, good.count)
        end
    until true

    ret.code = code
    return ret
end

-- 查询拍卖物
function clientCmd.reqQueryGoods(player, req)
    gLog.dump(req, "clientCmd.reqQueryGoods uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        if not req.type or not req.idx1 or not req.idx2 or not (req.idx2 >= req.idx1) then
            gLog.d("clientCmd.reqQueryGoods err1", player:getUid(), req.type, req.idx1, req.idx2)
            code = gErrDef.Err_ILLEGAL_PARAMS
            break
        end
        local pok, goods = xpcall(function()
            return commonLib:call(svrFunc.random(1, commonLib.serviceNum), "getGoods", req.type, req.idx1, req.idx2)
        end, svrFunc.exception)
        if not pok then
            gLog.d("clientCmd.reqQueryGoods err2", player:getUid(), req.type, req.idx1, req.idx2)
            code = gErrDef.Err_SERVICE_EXCEPTION
            break
        end
        ret.goods = goods
    until true

    ret.code = code
    return ret
end

return clientCmd
