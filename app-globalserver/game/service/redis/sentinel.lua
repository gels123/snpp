--[[
    redis哨兵
]]
local redis = require("redis-lua.src.redis")
local sentinel = class("sentinel")

function sentinel:masterFor(confs, name)
    for _, v in pairs(confs) do
        local ok, master = xpcall(function()
            local db = redis.connect(v.host, v.port)
            local r = db:raw_cmd("SENTINEL GET-MASTER-ADDR-BY-NAME " .. name .. "\r\n")
            db:quit()
            return r
        end, svrFunc.exception)
        if ok and master and #master >= 2 then
            return master[1], tonumber(master[2]) -- master's host, port
        end
    end
end

function sentinel:slaveFor(confs, name)
    for _, v in pairs(confs) do
        local ok, ip, port = xpcall(function()
            local db = redis.connect(v.host, v.port)
            local slaves = db:raw_cmd("SENTINEL SLAVES " .. name .. "\r\n")
            --gLog.dump(slaves, "sentinel:slaveFor slaves=")
            if slaves and type(slaves) == "table" then
                for _, sv in ipairs(slaves) do
                    local slave = {}
                    for i = 1, #sv, 2 do
                        slave[sv[i]] = sv[i + 1]
                    end
                    if slave["master-link-status"] == "ok" and slave["flags"] and not (string.find(slave["flags"], "s_down") or string.find(slave["flags"], "disconnected")) then
                        db:quit()
                        return slave["ip"], slave["port"]
                    end
                end
            end
            db:quit()
        end, svrFunc.exception)
        if ok and ip and port then
            return ip, port
        end
    end
    return self:masterFor(name, confs)
end

return sentinel