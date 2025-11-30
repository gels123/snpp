local setc = require "set.c"

local set = {}

-- 集合操作
set.OPERATE = {
	SET_OP_UNION = 0,
	SET_OP_DIFF = 1,
	SET_OP_INTER = 2,
}


local setmeta = {
	__index = set,
	__gc = function(self)
		print("call set gc ->")
		setc.release()
		-- for _, set in pairs(self.sets) do
		-- 	if set then
		-- 		setc.release(set)
		-- 	end
		-- end
	end,
}

function set:__checkSet( key )
	if not self.sets[key] then
		self.sets[key] = setc.new(key)
	end
end

-- 向集合添加一个或多个成员
function set:sadd(key, member, ...)
	if not key then return end
	self:__checkSet(key)
    return setc.sadd(key, member, ...)
end

-- 移除集合中一个或多个成员
function set:srem(key, member, ...)
	if not key then return end
    return setc.srem(key, member, ...)
end

-- 随机返回集合中一个元素
function set:srandmember(key)
	if not key then return end
    return setc.srandmember(key)
end

-- 判断 member 元素是否是集合 key 的成员
function set:ismember(key, member)
    return setc.ismember(key, member)
end

-- 返回所有给定集合的并集
function set:union(key, key2, ...)
    return setc.sunionDiffGenericCommand(self.OPERATE.SET_OP_UNION, key, key2, ...)
end

-- 返回所有给定集合的差集
function set:sdiff(key, key2, ...)
    return setc.sunionDiffGenericCommand(self.OPERATE.SET_OP_DIFF, key, key2, ...)
end

-- 返回所有给定集合的交集
function set:sinter(key, key2, ...)
    return setc.sinterGenericCommand(key, key2, ...)
end

-- 获取集合的成员数
function set:scard(key)
	if key then
	    return setc.scard(key)
	end
	return 0
end

-- 返回集合中的所有成员
function set:smembers(key)
	if key then
	    return setc.smembers(key)
	end
	return nil
end

-- 集合操作类
local M = {}

function M.new()
    local self = {}
    self.sets = {} --n个集合
    return setmetatable(self, setmeta)
end

return M

