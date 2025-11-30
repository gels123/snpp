--[[
    敏感词检测、过滤
]]
local sensitivewords = require("sensitivewords")
local mt = {}
mt.__index = mt

-- 加载敏感词字典
function mt:sensitiveWordLoadDict(path)
    if type(path) == "string" then
        self.sw:sensitiveWordLoadDict(path)
    end
end

-- 和谐敏感词
function mt:sensitiveWordReplace(text)
    if type(text) == "string" then
        return self.sw:sensitiveWordReplace(text, string.byte('*'))
    end
end

-- 检测字符串是否合法
function mt:sensitiveWordValidate(text)
    if type(text) == "string" then
        return self.sw:sensitiveWordValidate(text)
    end
end

local M = {}
function M.new()
    local obj = {
        sw = sensitivewords(),
    }
    return setmetatable(obj, mt)
end

return M

