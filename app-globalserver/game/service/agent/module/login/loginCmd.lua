--[[
	登录模块指令
]]
local skynet = require "skynet"
local svrFunc = require "svrFunc"
local svrAddrMgr = require "svrAddrMgr"
local agentCenter = require("agentCenter"):shareInstance()
local clientCmd = require "clientCmd"

-- 请求心跳
function clientCmd.reqHeartbeat(player, req)
    --gLog.dump(req, "clientCmd.reqHeartbeat uid="..tostring(player:getUid()))
    local loginCtrl = player:getModule(gModuleDef.loginModule)
    loginCtrl:reqHeartbeat()
    return {time = svrFunc.systemTime(),}
end

-- 请求更改心跳开关
function clientCmd.reqHeartbeatSwitch(player, req)
    --gLog.dump(req, "clientCmd.reqHeartbeatSwitch uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        local loginCtrl = player:getModule(gModuleDef.loginModule)
        loginCtrl:reqHeartbeatSwitch(req.close)
    until true

    ret.code = code
    return ret
end

-- 请求暂离
function clientCmd.reqAfk(player, req)
    --gLog.dump(req, "clientCmd.reqAfk uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        skynet.fork(function()
            --
            player:notifyMsg("notifyLogout", {flag = 2,}) -- 2=请求afk
            -- 调用gate玩家暂离
            skynet.fork(function()
                local gateSvr = svrAddrMgr.getSvr(svrAddrMgr.gateSvr, nil, dbconf.gamenodeid)
                skynet.send(gateSvr, "lua", "afk", player:getUid(), player:getSubid(), 2) --2=请求afk
            end)
        end)
    until true

    ret.code = code
    return ret
end

-- 请求离线
function clientCmd.reqLogout(player, req)
    --gLog.dump(req, "clientCmd.reqLogout uid="..tostring(player:getUid()))
    local ret = {}
    local code = gErrDef.Err_OK

    repeat
        skynet.fork(function()
            --
            player:notifyMsg("notifyLogout", {flag = 3,}) -- 3=请求离线
            --
            skynet.fork(function()
                local gateSvr = svrAddrMgr.getSvr(svrAddrMgr.gateSvr, nil, dbconf.gamenodeid)
                skynet.send(gateSvr, "lua", "logout", player:getUid(), player:getSubid(), 3)
            end)
        end)
    until true

    ret.code = code
    return ret
end

return clientCmd
