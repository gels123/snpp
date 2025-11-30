local conhash = require "conhash.c"

local mt = {}
mt.__index = mt

function mt:addnode(nodename, replica)
    local node = self.tbl[nodename]
    if not node then
        node = self.hash:addnode(nodename, replica)
        self.tbl[nodename] = node
        self.nodetbl[node] = nodename
        return true
    end
    return false
end

function mt:deletenode(nodename)
    local node = self.tbl[nodename]
    if node then
        local ok = self.hash:deletenode(node)
        if ok then
            self.tbl[nodename] = nil
            self.nodetbl[node] = nil
        end
        return ok
    end
    return false
end

function mt:count()
    return self.hash:count()
end

function mt:lookup(key)
    local node = self.hash:lookup(key)
    if node then
        local nodename = self.nodetbl[node]
        if nodename and self.tbl[nodename] and self.tbl[nodename] == node then
            return nodename
        end
    end
    return false
end

local M = {}
function M.new()
    local obj = {}
    obj.hash = conhash()
    obj.tbl = {}
    obj.nodetbl = {}
    return setmetatable(obj, mt)
end

return M

