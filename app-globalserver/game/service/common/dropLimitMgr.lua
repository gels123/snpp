--[[
    全局掉落管理器
]]
local skynet = require("skynet")
local svrFunc = require("svrFunc")
local playerDataLib = require("playerDataLib")
local commonCenter = require("commonCenter"):shareInstance()
local dropLimitMgr = class("dropLimitMgr")

function dropLimitMgr:ctor()
    self.module = "droplimitinfo"	    -- 数据表名
    self.data = nil		                -- 数据
end

-- 数据id
function dropLimitMgr:dataId()
    return commonCenter.kid * 100 + commonCenter.idx
end

-- 默认数据
function dropLimitMgr:defaultData()
    return {
        limits = {},
        time = 0,
    }
end

-- 初始化
function dropLimitMgr:init()
    self.data = self:queryDB()
    if "table" ~= type(self.data) then
        self.data = self:defaultData()
        self:updateDB()
    end
end

-- 查询数据库
function dropLimitMgr:queryDB()
    assert(self.module, "tradeMgr:queryDB error!")
    return playerDataLib:query(commonCenter.kid, self:dataId(), self.module)
end

-- 更新数据库
function dropLimitMgr:updateDB()
    local data = self:getDataDB()
    assert(self.module and data, "tradeMgr:updateDB error!")
    playerDataLib:sendUpdate(commonCenter.kid, self:dataId(), self.module, data)
end

-- 获取存库数据
function dropLimitMgr:getDataDB()
    return self.data
end

-- 检查全局掉落 items={{id=1001,count=1}}
function dropLimitMgr:dropLimit(items)
    if not items or #items <= 0 then
        return
    end
    local time = svrFunc.getWeehoursUTC()
    if self.data.time ~= time then
        self.data.time = time
        self.data.limits = {}
    end
    local limit, bSave = 10, false
    for i=#items,1,-1 do
        if items[i].id and items[i].count then
            local count = items[i].count + (self.data.limits[items[i].id] or 0)
            if count > limit then
                items[i].count = limit - (self.data.limits[items[i].id] or 0)
                self.data.limits[items[i].id] = limit
                if items[i].count <= 0 then
                    table.remove(items, i, 1)
                end
                bSave = true
            else
                self.data.limits[items[i].id] = count
                bSave = true
            end
        end
    end
    if bSave then
        self:updateDB()
    end
    return items
end

return dropLimitMgr