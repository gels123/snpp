--[[
    模拟客户端
]]
package.cpath =
        "skynet/luaclib/?.so;" ..
        "skynet/cservice/?.so;" ..
        "game/lib/lua-timer/?.so;" ..
        "game/lib/lua-lfs/?.so;" ..
        "game/lib/lua-bit32/?.so;" ..
        "game/lib/lua-json/?.so;"

package.path =
        "./?.lua;" ..
        "skynet/lualib/?.lua;" ..
        "skynet/lualib/compat10/?.lua;" ..
        "game/lib/?.lua;" ..
        "game/lib/lua-timer/?.lua;" ..
        "game/lib/lua-json/?.lua;" ..
        "game/service/proto/?.lua;" ..
        "game/service/simulate/?.lua;"

require "quickframework.init"
local simAgent = class("simAgent")


local host, port, uid = ...
host = tostring(host or "")
port = tonumber(port)
uid = tonumber(uid)
assert(host and type(port) == "number" and uid, "usage: ./client.sh host port uid")


-- 构造
function simAgent:ctor()
    self.simGate = require("simGate").new()
    self.simGate:addEventListener(self.simGate.Gate_Success, handler(self, self.connectGateOk))
end

-- 连接网关成功
function simAgent:connectGateOk(event)
    print("simAgent:connectGateOk =", host, port, uid, "index", self.simGate.index)
    self.simGate:handshake(uid)
end

-- 启动客户端
--print("simClient login host=", host, "port=", port, "uid=", uid)
local client = simAgent.new()
client.simGate:connectGate(host, port)



