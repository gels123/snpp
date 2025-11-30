--[[
    客户端指令
]]
local clientCmd = {}

local mt = {}

setmetatable(clientCmd, {
    __newindex = function(t, key, value)
        if mt[key] then
            gLog.e("clientCmd cmd reset", key, value)
        end
        rawset(mt, key, value)
    end,
    __index = mt,
})

return clientCmd