local lruc = require "lru.c"

local mt = {}
mt.__index = mt

function mt:dump()
    self.lru:dump()
end

function mt:set(key,value)
    return self.lru:set(key,value)
end

function mt:get(key)
    local err,ret = self.lru:get(key)
    if 0 == err then
        return ret,err
    end
    return nil,err
end

local M = {}
function M.new(capacity)
    local obj = {}
    obj.lru = lruc(capacity)
    return setmetatable(obj, mt)
end



return M

