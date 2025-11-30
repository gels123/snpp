--[[
	模块基类
]]
local skynet = require("skynet")
local playerDataLib = require("playerDataLib")
local agentCenter = require("agentCenter"):shareInstance()
local baseCtrl = class("baseCtrl")

-- [override]构造
function baseCtrl:ctor(uid)
    self.uid = assert(uid)              -- uid
    self.module = nil	                -- 数据表名
    self.data = nil		                -- 数据
    self.bInit = false                  -- 是否已初始化
end

-- [override]默认数据
function baseCtrl:defaultData()
	return {}
end

-- [override]初始化
function baseCtrl:init()
    if self.bInit then
        return
    end
	-- 设置已初始化
	self.bInit = true
    self.data = self:queryDB()
    if "table" ~= type(self.data) then
        self.data = self:defaultData()
        self:updateDB()
    end
end

-- [override]校验数据
function baseCtrl:check()

end

-- 是否已初始化
function baseCtrl:isInit()
    return self.bInit
end

-- 查询数据库
function baseCtrl:queryDB()
    assert(self.uid and self.module, "queryDB error!")
    return playerDataLib:query(agentCenter:getKid(), self.uid, self.module)
end

-- 更新数据库
function baseCtrl:updateDB()
    local data = self:getDataDB()
    assert(self.uid and self.module and data, "updateDB error!")
    playerDataLib:sendUpdate(agentCenter:getKid(), self.uid, self.module, data)
end

-- 获取存库数据
function baseCtrl:getDataDB()
    return self.data
end

-- [override]玩家login
function baseCtrl:login()

end

-- [override]玩家logout
function baseCtrl:logout()

end

-- [override]玩家checkin
function baseCtrl:checkin()

end

-- [override]玩家afk
function baseCtrl:afk()

end

-- [override]新的一天
function baseCtrl:onNewDay()

end

-- [override]获取登陆下发的初始化数据
function baseCtrl:getInitData()
    return self.data
end

-- 获取属性
function baseCtrl:getAttr(key)
    return self.data[key]
end

-- 获取属性
function baseCtrl:setAttr(key, val)
    self.data[key] = val
end

return baseCtrl