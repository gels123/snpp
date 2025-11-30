--[[
    开启调试
]]
local skynet = require ("skynet")

xpcall(function()
    print("=====fixdebug begin")

    -- 开启调试监听, 等待ide连接
    package.cpath = package.cpath .. '/Users/gels/Documents/work/sn-login-server/?.dylib'
    print("=====fixdebug 1")
    local port = 9966
    local dbg = require("emmy_core") -------------
    print("=====fixdebug 2")
    print("=====fixdebug", port, dbg)
    local ok = dbg.tcpListen('0.0.0.0', port)
    -- dbg.waitIDE(); dbg.breakHere()
    print("fixdebug start debugger success", skynet.self(), port, ok)

        -- if self.scene.serverId == 2 then
    --     require("fixdebug")
    --     skynet.sleep(1000)
    -- end

  

    print("=====fixdebug end")
end, debug.traceback)