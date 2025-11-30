--[[
    玩家数据中心配置
--]]
local skynet = require "skynet"
local redisLib = require("redisLib")
local playerDataConfig = class("playerDataConfig")

-- redis数据类型（按业务分类）
gRedisType = {
    -- 玩家数据类型, 一个玩家对应一个哈希表, 存放多个模块数据
    player = {
        key = function(kid, id, module) return string.format("game-player-%s-%s", kid, id) end,
        get = function(key, id, module) return redisLib:hGet(key, module) end,
        set = function(key, id, module, data) return redisLib:hSet(key, module, data) end,
        del = function(key, id, module) redisLib:hDel(key, module) end
    },
    -- 联盟数据类型, 一个联盟对应一个哈希表, 存放多个模块数据
    alliance = {
        key = function(kid, id, module) return string.format("game-alliance-%s-%s", kid, id) end,
        get = function(key, id, module) return redisLib:hGet(key, module) end,
        set = function(key, id, module, data) return redisLib:hSet(key, module, data) end,
        del = function(key, id, module) redisLib:hDel(key, module) end
    },
    -- 王国数据类型, 一个王国对应一个哈希表, 存放多个模块数据
    kingdom = {
        key = function(kid, id, module) return string.format("game-kingdom-%s-%s", kid, id) end,
        get = function(key, id, module) return redisLib:hGet(key, module) end,
        set = function(key, id, module, data) return redisLib:hSet(key, module, data) end,
        del = function(key, id, module) redisLib:hDel(key, module) end
    },
    -- 通用数据类型, 一个王国-一个模块-一个ID对应一个key-value
    common = {
        key = function(kid, id, module) return string.format("game-%s-%s-%s", kid, module, id) end,
        get = function(key, id, module) return redisLib:get(key) end,
        set = function(key, id, module, data) return redisLib:set(key, data) end,
        del = function(key, id, module) redisLib:delete(key) end
    },
}

--[[
    模块配置
    @table [必填]数据表名
    @columns [需落地必填/不落地不填] 字段列表
    @keyColumns [需落地必填/不落地不填] 主键[索引]字段
    @dataColumns [需落地必填/不落地不填] 普通字段: 查询/更新时处理的字段，通常为{"data"}, 有配置则查询/更新将处理这些字段, 一般"data"字段放第1位
    @redisType [必填]本地redis数据类型, 参见gRedisType
    @queryResultCallback [选填]自定义返回数据处理方法，不配置使用默认处理方法
]]
playerDataConfig.moduleSettings = {
    -- 联盟信息, 存到联盟哈希表, 且落库
    ["alliance"] = {
        ["table"] = "alliance",
        ["columns"] = {"_id", "data", "kid"},
        ["keyColumns"] = {"_id"},
        ["dataColumns"] = {"data", "kid"},
        ["redisType"] = gRedisType.alliance,
    },
    -- 联盟缓存数据, 存到联盟哈希表, 且落库
    ["cachealliance"] = {
        ["table"] = "cachealliance",
        ["columns"] = {"_id", "data"},
        ["keyColumns"] = {"_id"},
        ["dataColumns"] = {"data"},
        ["redisType"] = gRedisType.alliance,
    },
    -- 全局掉落信息, 存到王国哈希表, 且落库
    ["droplimitinfo"] = {
        ["table"] = "droplimitinfo",
        ["columns"] = {"_id", "data"},
        ["keyColumns"] = {"_id"},
        ["dataColumns"] = {"data"},
        ["redisType"] = gRedisType.kingdom,
    },
    -- 玩家拍卖行信息, 存到玩家哈希表, 且落库
    ["tradeinfo"] = {
        ["table"] = "tradeinfo",
        ["columns"] = {"_id", "data"},
        ["keyColumns"] = {"_id"},
        ["dataColumns"] = {"data"},
        ["redisType"] = gRedisType.player,
    },
    -- 拍卖行信息, 存到王国哈希表, 且落库
    ["tradegoods"] = {
        ["table"] = "tradegoods",
        ["columns"] = {"_id", "data"},
        ["keyColumns"] = {"_id"},
        ["dataColumns"] = {"data"},
        ["redisType"] = gRedisType.kingdom,
    },
    -- 聊天信息, 存到玩家哈希表, 且落库
    ["chatinfo"] = {
        ["table"] = "chatinfo",
        ["columns"] = {"_id", "data"},
        ["keyColumns"] = {"_id"},
        ["dataColumns"] = {"data"},
        ["redisType"] = gRedisType.player,
    },
    -- 聊天信息, 存到玩家哈希表, 且落库
    ["chat"] = {
        ["table"] = "chat",
        ["columns"] = {"_id", "data"},
        ["keyColumns"] = {"_id"},
        ["dataColumns"] = {"data"},
        ["redisType"] = gRedisType.common,
    },
}

-- 获取本地redis数据类型
function playerDataConfig:getRedisType(module)
    return playerDataConfig.moduleSettings[module] and playerDataConfig.moduleSettings[module].redisType
end

-- 校验配置
function playerDataConfig:check()
    for module,v in pairs(playerDataConfig.moduleSettings) do
        assert(v.table, string.format("playerDataConfig:check error1: module=%s", module))
        assert(v.redisType, string.format("playerDataConfig:check error2: module=%s", module))
        if v.columns then -- 落库
            assert(v.columns and next(v.columns) and v.keyColumns and next(v.keyColumns) and v.dataColumns and next(v.dataColumns), string.format("playerDataConfig:check error3: module=%s", module))
            -- assert(#v.columns == (#v.keyColumns + #v.dataColumns), string.format("playerDataConfig:check error4: module=%s", module))
        else -- 不落库
           assert(v.keyColumns == nil and v.dataColumns == nil, string.format("playerDataConfig:check error5: module=%s", module))
        end
    end
    -- gLog.dump(playerDataConfig.moduleSettings, "playerDataConfig:check ok=", 10)
end

playerDataConfig:check()

return playerDataConfig