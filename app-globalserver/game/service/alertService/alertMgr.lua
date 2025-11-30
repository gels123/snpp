--[[
    报错信息推送服务管理
]]
local skynet = require("skynet")
local dbconf = require("dbconf")
local alertMgr = class("alertMgr")

-- md text format
local mdFormatStr = "**tag:%s nodeid:%s service%s count:%s**\n\n**desc:**\n>%s"

function alertMgr:init()
    -- 机器人
    self.robot = nil
    -- 文本缓存
    self.textTab = {}
end

function alertMgr:push(desc, from)
    local count = self.textTab[desc]
    if count then
        self.textTab[desc] = count + 1
        return
    else
        self.textTab[desc] = 1
        skynet.sleep(500)
        count = self.textTab[desc]
        self.textTab[desc] = nil
        self:pushToRobot(desc, count, from)
    end
end

function alertMgr:pushToRobot(desc, count, from)
    if not self.robot and dbconf.robotUrl then
        --self.robot = require("wxRobot").new(dbconf.robotUrl)
        self.robot = require("ddRobot").new(dbconf.robotUrl)
    end
    if self.robot then
        local text = string.format(mdFormatStr, dbconf.robotTag, dbconf.globalnodeid, skynet.address(from), count, desc)
        self.robot:pushMD("error msg", text)
    end
end

return alertMgr