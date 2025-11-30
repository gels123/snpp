--[[
	本地静态配置数据接口
]]
local skynet = require "skynet"
local sharedata = require "sharedata"
local sharedataLib = {}

setmetatable(sharedataLib, {__index = function(t, k)
	return sharedataLib.query(k)
end})

local queryCount, queryRecord = 0, {}

-- 查询
function sharedataLib.query(name)
	if not queryRecord[name] then
		queryCount = queryCount + 1
	end
	queryRecord[name] = (queryRecord[name] or 0) + 1
	return sharedata.query(name)
end

-- 新增
function sharedataLib.new(name, v)
	sharedata.new(name, v)
end

-- 更新
function sharedataLib.update(name, v)
	sharedata.update(name, v)
end

-- 删除
function sharedataLib.delete(name)
	sharedata.delete(name)
end

-- 获取查询数量
function sharedataLib.getQueryCount()
	return queryCount, queryRecord
end

return sharedataLib
