--[[
	聊天模块指令
]]
local skynet = require "skynet"
local svrFunc = require "svrFunc"
local chatLib = require "chatLib"
local agentCenter = require("agentCenter"):shareInstance()
local clientCmd = require "clientCmd"

-- 请求聊天/好友信息 reqChatInfo
function clientCmd.reqChatInfo(player, req)
    gLog.dump(req, "clientCmd.reqChatInfo uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        local chatCtrl = player:getModule(gModuleDef.chatModule)
        ret.friends = chatCtrl:getAttr("friends")
        ret.apply = chatCtrl:getAttr("apply")
        ret.blacks = chatCtrl:getAttr("blacks")
        ret.rooms = chatCtrl:getAttr("rooms")
    until true

    ret.code = code
    return ret
end

-- 请求添加好友 reqApply uid=1001
function clientCmd.reqApply(player, req)
    gLog.dump(req, "clientCmd.reqApply uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        local chatCtrl = player:getModule(gModuleDef.chatModule)
        local ok, code2 = chatCtrl:addApply(req.uid)
        if not ok then
            gLog.d("clientCmd.reqApply err1", player:getUid(), req.uid)
            code = code2 or gErrDef.Err_SERVICE_EXCEPTION
            break
        end
    until true

    ret.code = code
    return ret
end

-- 回应添加好友 reqRspApply uid=1000 flag=true
function clientCmd.reqRspApply(player, req)
    gLog.dump(req, "clientCmd.reqRspApply uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        local chatCtrl = player:getModule(gModuleDef.chatModule)
        local ok, code2 = chatCtrl:rspApply(req.uid, req.flag)
        if not ok then
            gLog.d("clientCmd.reqRspApply err1", player:getUid(), req.uid)
            code = code2 or gErrDef.Err_SERVICE_EXCEPTION
            break
        end
    until true

    ret.code = code
    return ret
end

-- 请求添加/删除黑名单 reqSetBlacks uid=1001 flag=false
function clientCmd.reqSetBlacks(player, req)
    gLog.dump(req, "clientCmd.reqSetBlacks uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        local chatCtrl = player:getModule(gModuleDef.chatModule)
        local ok, code2 = chatCtrl:setBlacks(req.uid, req.flag)
        if not ok then
            gLog.d("clientCmd.reqSetBlacks err1", player:getUid(), req.uid)
            code = code2 or gErrDef.Err_SERVICE_EXCEPTION
            break
        end
    until true

    ret.code = code
    return ret
end

-- 请求发送聊天消息
function clientCmd.reqChat(player, req)
    gLog.dump(req, "clientCmd.reqChat uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        local chatCtrl = player:getModule(gModuleDef.chatModule)
        local roomId = chatCtrl:getRoomId(req.uid, req.roomId)
        if not roomId then
            gLog.d("clientCmd.reqChat err1", player:getUid(), req.uid)
            code = gErrDef.Err_ILLEGAL_PARAMS
            break
        end
        local callok, ok, code2 = xpcall(function()
            return chatLib:call(roomId, "chat", roomId, req.msg)
        end, svrFunc.exception)
        if not callok or not ok then
            gLog.d("clientCmd.reqChat err2", player:getUid(), req.uid)
            code = code2 or gErrDef.Err_SERVICE_EXCEPTION
            break
        end
    until true

    ret.code = code
    return ret
end

return clientCmd
