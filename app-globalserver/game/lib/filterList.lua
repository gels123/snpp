--[[
	过滤队列
]]
local skynet = require("skynet")
local zset = require("zset")
local filterList = class("filterList")

function filterList:ctor()
	self.dataList = {}
    self.sortSet = zset.new()
end

function filterList:push(id, data)
    id = tostring(id)
    self.dataList[id] = data
    self.sortSet:add(skynet.time(), id)
end

function filterList:remove(id)
    id = tostring(id)
    if self:has(id) then
        local data = self.dataList[id]
        self.dataList[id] = nil
        self.sortSet:rem(id)
        return data
    end
end

function filterList:get(id)
    return self.dataList[id]
end

function filterList:has(id)
    if self.dataList[id] then
        return true
    end
end

function filterList:keys(key)
    local ret = {}
    for k,_ in pairs(self.dataList) do
        if string.find(k, key) then
            table.insert(ret, k)
        end
    end
    return ret
end

function filterList:pop()
    local range = self.sortSet:range(1, 1)
    if range and range[1] then
        local id = tostring(range[1])
        local data = self.dataList[id]
        self.sortSet:rem(id)
        if self.dataList[id] then
            self.dataList[id] = nil
        end
        return data
    end
end

function filterList:count()
    return self.sortSet:count()
end

return filterList