--[[
  客户端请求分发
    请求数据格式 = { 
      cmd = xxx -- 模块的指令头
      subcmd = xxx -- 模块的具体操作类型
      data = {} --发送的数据
    }
    返回数据格式 = {
      cmd = xxx -- 模块的指令头
      subcmd = xxx -- 模块的具体操作类型
      data = {} -- 发送的数据
      err = xxx -- 错误类型
    }
]]
local skynet = require "skynet"
local msgCtrl = {}

local dispatch = {}

-- 注册消息处理回调
function msgCtrl.register(cmd, subcmd, cb)
  cmd, subcmd = tostring(cmd), tostring(subcmd)
  assert(cmd and subcmd and "function" == type(cb),  string.format("msgCtrl.register failed: param invalid! %s %s %s", cmd, subcmd, cb))
  
  if not dispatch[cmd] then
    dispatch[cmd] = {}
  end
  assert(not dispatch[cmd][subcmd], string.format("msgCtrl.register failed: register repeated! %s %s %s", cmd, subcmd, cb))

  dispatch[cmd][subcmd] = cb
end

-- 移除消息处理回调
function msgCtrl.remove(cmd, subcmd)
  cmd, subcmd = tostring(cmd), tostring(subcmd)
  if dispatch[cmd] and dispatch[cmd][subcmd] then
    dispatch[cmd][subcmd] = nil
  end
end

-- 移除所有消息处理回调
function msgCtrl.clean()
  dispatch = {}
end

-- 消息分发
function msgCtrl.handle(req)
  local cmd, subcmd = tostring(req.cmd), tostring(req.subcmd)
  return xpcall(function ()
    local cb = dispatch[cmd] and dispatch[cmd][subcmd]
    if "function" ~= type(cb) then
      gLog.e("msgCtrl.handle failed! not found the command: cmd=", cmd, ",subcmd=", subcmd)
    end
    return cb(req)
  end, svrFunc.exception)
end

return msgCtrl
