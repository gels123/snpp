local skynet = require("skynet")
local svrAddrMgr = require("svrAddrMgr")
local alertLib = {}

-- 报警
function alertLib:alert(desc, from)
    -- 报警服务本身不需要报警, 不然死循环
    local address = svrAddrMgr.getSvr(svrAddrMgr.alertSvr)
    if not from or address == from then
        --gLog.w("alertLib:alert ignore=", alertLevel, desc, skynet.address(from))
        return
    end
    skynet.send(address, "lua", "alert", desc, from)
end

return alertLib