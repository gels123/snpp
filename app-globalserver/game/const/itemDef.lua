--[[
	背包/道具定义
]]

-- 背包类型定义
gBackpackDef =
{
   PROPS = 1,        -- 道具背包
   MATERIAL = 2,     -- 材料背包
   JEWEL = 3,        -- 宝石背包
}

-- 背包类型容量上限
gBackpackMaxSize =
{
   [gBackpackDef.PROPS] = 100,        -- 道具背包
   [gBackpackDef.MATERIAL] = 100,     -- 材料背包
   [gBackpackDef.JEWEL] = 100,        -- 宝石背包
}

-- 道具类型定义
gItemTypeDef =
{
   CURRENCY = 1,              -- 货币
   ITEM_CURRENCY = 2,         -- 货币道具：使用获得货币
   ITEM_NO_EFFECT = 3,        -- 无效果类道具：无使用条件且无使用效果
   ITEM_REWARD_PACK = 4,      -- 礼包道具：使用获得随机道具奖励
}

-- 常用道具ID
gItemIdCommon =
{
   GOLD = 1,                  -- 金币
   DIAMOND = 2,               -- 钻石
}
