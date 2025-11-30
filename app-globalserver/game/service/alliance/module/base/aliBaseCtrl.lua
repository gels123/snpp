--[[
	模块基类
]]
local skynet = require("skynet")
local playerDataLib = require("playerDataLib")
local allianceCenter = require("allianceCenter"):shareInstance()
local aliBaseCtrl = class("aliBaseCtrl")

-- [override]构造
function aliBaseCtrl:ctor(aid)
    self.aid = tostring(aid)            -- 联盟ID
    self.module = nil	                -- 数据表名
    self.data = nil		                -- 数据
    self.bInit = false                  -- 是否已初始化
end

-- [override]默认数据
function aliBaseCtrl:defaultData()
	return {}
end

-- [override]初始化
function aliBaseCtrl:init()
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

-- 是否已初始化
function aliBaseCtrl:isInit()
    return self.bInit
end

-- 查询数据库
function aliBaseCtrl:queryDB()
    assert(self.module, "aliBaseCtrl:queryDB error!")
    return playerDataLib:query(allianceCenter.kid, self.aid, self.module)
end

-- 更新数据库
function aliBaseCtrl:updateDB()
    local data = self:getDataDB()
    assert(self.module and data, "aliBaseCtrl:updateDB error!")
    playerDataLib:sendUpdate(allianceCenter.kid, self.aid, self.module, data)
end

-- 获取存库数据
function aliBaseCtrl:getDataDB()
    return self.data
end

-- [override]获取登陆下发的初始化数据
function aliBaseCtrl:getInitData()
    return self.data
end

return aliBaseCtrl