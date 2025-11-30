--[[
	联盟主信息
]]
local skynet = require("skynet")
local allianceCenter = require("allianceCenter"):shareInstance()
local aliBaseCtrl = require("aliBaseCtrl")
local aliInfoCtrl = class("aliInfoCtrl", aliBaseCtrl)

-- 构造
function aliInfoCtrl:ctor(aid)
    self.super.ctor(self, aid)

    self.module = "alliance"    -- 数据表名
    self.data = nil             -- 数据
    self.blackListCnt = 0       -- 黑名单数量
end

-- 初始化
function aliInfoCtrl:init()
    if self.bInit then
        return
    end
    -- 设置已初始化
    self.bInit = true
    self.data = self:queryDB()
    if self.data then
        self.data = self.data.data
    end
    if "table" ~= type(self.data) then
        self.data = self:defaultData()
        self:updateDB()
    end

    self.blackListCnt = table.nums(self.data.blacklist)
end

-- 默认数据
function aliInfoCtrl:defaultData()
    return {
        aid = self.aid,                         -- 联盟ID
        name = "",                              -- 联盟名字
        abbr = "",                              -- 联盟简称
        leader = 0,                             -- 联盟盟主
        flag = "1",                             -- 联盟旗帜(默认是"1", 或cdn链接)
        language = "",                          -- 联盟语种
        limitCount = gAliMaxMemberNum,          -- 联盟最大成员数量
        recruitType = gAliRecruit.public,       -- 招募类型
        manifesto = "",                         -- 联盟宣言
        notice = "",                            -- 联盟公告
        rankNames = {},                         -- 联盟阶级1-5的称谓
        memberlist = {},                        -- 成员列表
        applylist = {},                         -- 申请列表
        invitelist = {},                        -- 邀请列表
        permission = {},                        -- 联盟权限
        creatTime = 0,                          -- 创建时间
        blacklist = {},                         -- 黑名单
    }
end

-- 更新数据库
function aliInfoCtrl:updateDB()
    local data = self:getDataDB()
    assert(self.module and data, "aliInfoCtrl:updateDB error!")
    require("playerDataLib"):sendUpdate(allianceCenter.kid, self.aid, self.module, {id = self.aid, data = data, kid = allianceCenter.kid}, true)
end

function aliInfoCtrl:getAid()
    return self.data.aid
end

-- 获取所有联盟成员UID
function aliInfoCtrl:getMemberUids()
    if self.data then
        return table.keys(self.data.memberlist)
    end
end

-- 添加联盟成员
function aliInfoCtrl:addMember(uid)
    if self.data.memberlist[uid] then
        return false
    end
    self.data.memberlist[uid] = {}
    -- 更新数据库
    self:updateDB()
    return true
end

-- 获取联盟信息
function aliInfoCtrl:getAilInfos(keys)
    if keys == nil then
        return self.data
    else
        local ret = {}
        for _,key in pairs(keys) do
            ret[key] = self.data[key]
        end
        return ret
    end
end

-- 更新黑名单列表
function aliInfoCtrl:updateBlackList(uid, bAdd)
    local bSave = false
    local noticeMsg = {}
    if bAdd then
        --加黑名单
        if self.blackListCnt >= localDataUtils.getConfigDataValue(gConfigId.friendMaxBlackListCount) then
            return gErrDef.Err_Friend_BlackList_Count_Limit
        end
        if not self.data.blacklist[uid] then
            local info = cacheLib:getPlayerAttrs(allianceCenter.kid, uid, gFriendCacheFields)
            if info then
                self.blackListCnt = self.blackListCnt + 1
                self.data.blacklist[uid] = {}
                noticeMsg.blackAdd = info
                bSave = true
            else
                gLog.w("aliInfoCtrl:updateBlackList warn1", allianceCenter.kid, uid)
                return gErrDef.Err_Friend_Not_Find_Player_Info
            end
        end
    else
        --移除黑名单
        if self.data.blacklist[uid] then
            self.blackListCnt = self.blackListCnt - 1
            self.data.blacklist[uid] = nil
            noticeMsg.blackDel = uid
            bSave = true
        else
            return gErrDef.Err_Friend_Not_In_Black_List
        end
    end
    if bSave then
        self:updateDB()
        -- 推送给所有联盟成员
        skynet.fork(function()
            allianceCenter:notifyMsg(self.aid, "notifyBlackList", noticeMsg)
        end)
    end
    return gErrDef.Err_OK
end

-- 请求更新联盟信息
function aliInfoCtrl:reqUpdateInfo(req)
    local bSave = false
    if req.name and req.name ~= "" and req.name ~= self.data.name then
        bSave = true
        self.data.name = req.name
    end
    if req.abbr and req.abbr ~= "" and req.abbr ~= self.data.abbr then
        bSave = true
        self.data.abbr = req.abbr
    end
    if req.flag and req.flag ~= "" and req.flag ~= self.data.flag then
        bSave = true
        self.data.flag = req.flag
    end
    if req.language and req.language ~= "" and req.language ~= self.data.language then
        bSave = true
        self.data.language = req.language
    end
    if req.recruitType and req.recruitType ~= self.data.recruitType then
        bSave = true
        self.data.recruitType = req.recruitType
    end
    if req.manifesto and req.manifesto ~= "" and req.manifesto ~= self.data.manifesto then
        bSave = true
        self.data.manifesto = req.manifesto
    end
    if req.notice and req.notice ~= "" and req.notice ~= self.data.notice then
        bSave = true
        self.data.notice = req.notice
    end
    if bSave then
        -- 更新数据库
        self:updateDB()
        -- 推送给所有联盟成员
        skynet.fork(function()
            allianceCenter:notifyMsg(self.aid, "notifyAliUpdateInfo", req)
        end)
        return true
    end
    return false
end

return aliInfoCtrl

