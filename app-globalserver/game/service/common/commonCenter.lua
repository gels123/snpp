--[[
	公共杂项服务中心
]]
local skynet = require "skynet"
local serviceCenterBase = require("serviceCenterBase2")
local commonCenter = class("commonCenter", serviceCenterBase)

-- 构造
function commonCenter:ctor()
	commonCenter.super.ctor(self)
end

-- 初始化
function commonCenter:init(kid, idx)
	gLog.i("==commonCenter:init begin==", kid, idx)

	-- 王国ID、索引
	self.kid = kid
	self.idx = idx
	-- 全局掉落管理器
	self.dropLimitMgr = require("dropLimitMgr").new()
	self.dropLimitMgr:init()
	-- 拍卖行管理器
	self.tradeMgr = require("tradeMgr").new()
	self.tradeMgr:init()

    gLog.i("==commonCenter:init end==", kid, idx)
end

--->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 全局掉落 begin >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- 检查全局掉落 items={{id=1001,count=1}}
function commonCenter:dropLimit(items)
	return self.dropLimitMgr:dropLimit(items)
end
---<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< 全局掉落 end <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


--->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 拍卖行 begin >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- 添加拍卖物
function commonCenter:addGoods(good)
	return self.tradeMgr:addGoods(good)
end

-- 撤回拍卖物
function commonCenter:remGoods(uid, type, idx)
	return self.tradeMgr:remGoods(uid, type, idx)
end

-- 购买拍卖物
function commonCenter:buyGood(uid, type, idx, id, gold)
	return self.tradeMgr:buyGood(uid, type, idx, id, gold)
end

-- 获取拍卖物
function commonCenter:getGoods(type, idx1, idx2)
	return self.tradeMgr:getGoods(type, idx1, idx2)
end

-- 获取单个拍卖物
function commonCenter:getGood(type, idx)
	return self.tradeMgr:getGood(type, idx)
end
---<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< 拍卖行 end <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

return commonCenter
