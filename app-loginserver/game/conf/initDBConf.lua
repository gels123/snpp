--[[
    服务器配置
]]
local skynet = require("skynet")
local cluster = require("cluster")
local dbconf = require("dbconf")
local initDBConf = class("initDBConf")

-- 共享数据KEY
local SVRCONF_CONF_KEY_CLUSTER = "SVRCONF_CONF_KEY_CLUSTER"
local SVRCONF_CONF_KEY_DEBUG = "SVRCONF_CONF_KEY_DEBUG"
local SVRCONF_CONF_KEY_HTTP = "SVRCONF_CONF_KEY_HTTP"
local SVRCONF_CONF_KEY_KINGDOM = "SVRCONF_CONF_KEY_KINGDOM"
local SVRCONF_CONF_KEY_LOGIN = "SVRCONF_CONF_KEY_LOGIN"
local SVRCONF_CONF_KEY_GLOBAL = "SVRCONF_CONF_KEY_GLOBAL"
local SVRCONF_CONF_KEY_GATE = "SVRCONF_CONF_KEY_GATE"
local SVRCONF_CONF_KEY_NOTICE_HTTP = "SVRCONF_CONF_KEY_NOTICE_HTTP"
local SVRCONF_CONF_KEY_IP_WHITE_LIST = "SVRCONF_CONF_KEY_IP_WHITE_LIST"
local SVRCONF_CONF_KEY_GATE_PVP = "SVRCONF_CONF_KEY_GATE_PVP"

-- 加载服务器配置
function initDBConf:set(isUpdate)
    gLog.i("==initDBConf:set begin==", isUpdate)

    -- 设置cluster配置
    self:setClusterConf(isUpdate)
    -- 设置debug配置
    self:setDebugConf(isUpdate)
    -- 设置http配置
    self:setHttpConf(isUpdate)
    -- 设置kingdom配置
    self:setKingdomConf(isUpdate)
    -- 设置login配置
    self:setLoginConf(isUpdate)
    -- 设置login配置
    self:setGlobalConf(isUpdate)
    -- 设置gate配置
    self:setGateConf(isUpdate)
    -- 设置notice http配置
    self:setNoticeHttp(isUpdate)
    -- 设置ip白名单配置
    self:setIpWhiteListConf(isUpdate)
    -- 设置战斗服gate配置
    self:setGatePvpConf(isUpdate)

    -- 重新加载cluster配置
    local cluster = require("cluster")
    cluster.reload()

    -- 查询关联
    self.sharedataRef = {}
    -- self:dump()
    gLog.i("==initDBConf:set end==", isUpdate)

    return true
end

-- 设置cluster配置
function initDBConf:setClusterConf(isUpdate)
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_cluster")
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_cluster"
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k,v in pairs(ret) do
        assert(v.nodeid and v.nodename and v.ip and v.web and v.listen and v.listennodename and v.port and v.type)
        values[v.nodeid] = v
    end
    gLog.dump(values, "initDBConf:setClusterConf values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_CLUSTER, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_CLUSTER, values)
    end

    -- 写入本地cluster配置文件
    local content = ""
    for k, v in pairs(values) do
        if v.web ~= "127.0.0.1" and v.web ~= "localhost" then
            local cell = string.format("%s = \"%s:%s\"", v.nodename, v.web, v.port)
            content = content .. cell .. "\n"
        else
            local cell = string.format("%s = \"%s:%s\"", v.nodename, v.ip, v.port)
            content = content .. cell .. "\n"
        end
        local cell2 = string.format("%s = \"%s:%s\"", v.listennodename, v.listen, v.port)
        content = content .. cell2 .. "\n"
    end
    local filename = skynet.getenv("cluster")
    local file = assert(io.open(filename, 'w'))
    file:write(content)
    file:close()
end

-- 获取cluster配置
function initDBConf:getClusterConf(nodeid)
    return self:getConf(SVRCONF_CONF_KEY_CLUSTER, nodeid)
end

-- 设置debug配置
function initDBConf:setDebugConf(isUpdate)
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_debug")
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_debug"
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k,v in pairs(ret) do
        assert(v.nodeid and v.ip and v.web and v.port)
        values[v.nodeid] = v
    end
    -- gLog.dump(values, "initDBConf:setDebugConf values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_DEBUG, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_DEBUG, values)
    end
end

-- 获取debug配置
function initDBConf:getDebugConf(nodeid)
    return self:getConf(SVRCONF_CONF_KEY_DEBUG, nodeid)
end

-- 设置http配置
function initDBConf:setHttpConf(isUpdate) 
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_http")
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_http"
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k,v in pairs(ret) do
        assert(v.nodeid and v.host and v.web and v.listen and v.port and v.instance and v.limitbody)
        values[v.nodeid] = v
    end
    -- gLog.dump(values, "initDBConf:setHttpConf values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_HTTP, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_HTTP, values)
    end
end

-- 获取http配置
function initDBConf:getHttpConf(nodeid)
    return self:getConf(SVRCONF_CONF_KEY_HTTP, nodeid)
end

-- 设置kingdom配置
function initDBConf:setKingdomConf(isUpdate)
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_kingdom")
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_kingdom"
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k,v in pairs(ret) do
        assert(v.kid and v.nodeid and v.status and v.startTime and v.isNew)
        local conf = self:getClusterConf(v.nodeid)
        table.merge(v, conf or {})
        if v.type == 3 then --cluster集群类型: 1登陆服 2全局服 3游戏服
            values[v.kid] = v
        else
            gLog.e("initDBConf:setKingdomConf invalid", v.nodeid, v.type)
        end
    end
    --gLog.dump(values, "initDBConf:setKingdomConf values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_KINGDOM, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_KINGDOM, values)
    end
end

-- 获取kingdom配置
function initDBConf:getKingdomConf(kid)
    return self:getConf(SVRCONF_CONF_KEY_KINGDOM, kid)
end

-- 设置login配置
function initDBConf:setLoginConf(isUpdate)
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_login")
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_login"
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k,v in pairs(ret) do
        assert(v.nodeid and v.host and v.web and v.listen and v.port and v.instance and v.mastername and v.limitbody)
        local conf = self:getClusterConf(v.nodeid)
        if conf and conf.type == 1 then --cluster集群类型: 1登陆服 2全局服 3游戏服
            values[v.nodeid] = v
        else
            gLog.e("initDBConf:setLoginConf invalid", v.nodeid, conf and conf.type)
        end
    end
    -- gLog.dump(values, "initDBConf:setLoginConf values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_LOGIN, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_LOGIN, values)
    end
end

-- 获取login配置(仅login服节点有该配置)
function initDBConf:getLoginConf(nodeid)
    return self:getConf(SVRCONF_CONF_KEY_LOGIN, nodeid)
end

-- 设置global配置
function initDBConf:setGlobalConf(isUpdate)
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_cluster", {type = 2})
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_cluster where type ='2'" --cluster集群类型: 1登陆服 2全局服 3游戏服
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k,v in pairs(ret) do
        assert(v.nodeid and v.nodename and v.ip and v.web and v.listen and v.listennodename and v.port and v.type)
        if v.type == 2 then
            values[v.nodeid] = v
        end
    end
    -- gLog.dump(values, "initDBConf:setGlobalConf values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_GLOBAL, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_GLOBAL, values)
    end
end

-- 获取global配置
function initDBConf:getGlobalConf(nodeid)
    return self:getConf(SVRCONF_CONF_KEY_GLOBAL, nodeid)
end

-- 设置gate配置
function initDBConf:setGateConf(isUpdate)
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_gate")
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_gate"
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k,v in pairs(ret) do
        assert(v.nodeid and v.web and v.address and v.proxy and v.listen and v.port)
        values[v.nodeid] = v
    end
    -- gLog.dump(values, "initDBConf:setGateConf values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_GATE, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_GATE, values)
    end
end

-- 获取gate配置(仅game服和global服节点有该配置)
function initDBConf:getGateConf(nodeid)
    return self:getConf(SVRCONF_CONF_KEY_GATE, nodeid)
end

-- 设置notice http配置
function initDBConf:setNoticeHttp(isUpdate)
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_noticehttp")
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_noticehttp"
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k,v in pairs(ret) do
        assert(v.id and v.host and v.url)
        values[v.id] = v
    end
    -- gLog.dump(values, "initDBConf:setNoticeHttp values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_NOTICE_HTTP, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_NOTICE_HTTP, values)
    end
end

-- 设置notice http配置
function initDBConf:getNoticeHttpConf()
    return self:getConf(SVRCONF_CONF_KEY_NOTICE_HTTP)
end

-- 设置ip白名单配置
function initDBConf:setIpWhiteListConf(isUpdate)
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_ipwhitelist")
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_ipwhitelist"
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k, v in pairs(ret) do
        assert(v.nodeid and v.ipList and v.status)
        values[v.nodeid] = v
    end
    -- gLog.dump(values, "initDBConf:setIpWhiteListConf values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_IP_WHITE_LIST, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_IP_WHITE_LIST, values)
    end
end

-- 获取ip白名单配置
function initDBConf:getIpWhiteListConf(nodeid)
    return self:getConf(SVRCONF_CONF_KEY_IP_WHITE_LIST, nodeid)
end

-- 设置战斗服gate配置
function initDBConf:setGatePvpConf(isUpdate)
    local svrAddrMgr = require("svrAddrMgr")
    local ret
    local address = svrAddrMgr.getSvr(svrAddrMgr.confDBSvr)
    if dbconf.dbtype == "mongodb" then
        ret = skynet.call(address, "lua", "find", nil, "conf_gatepvp")
    elseif dbconf.dbtype == "mysql" then
        local sql = "select * from conf_gatepvp"
        ret = skynet.call(address, "lua", "execute", sql)
    else
        assert(false, "dbtype error"..tostring(dbconf.dbtype))
    end
    local values = {}
    for k,v in pairs(ret) do
        assert(v.nodeid and v.web and v.address and v.proxy and v.listen and v.port)
        values[v.nodeid] = v
    end
    -- gLog.dump(values, "initDBConf:setGateConf values=", 10)
    local sharedataLib = require("sharedataLib")
    if isUpdate then
        sharedataLib.update(SVRCONF_CONF_KEY_GATE_PVP, values)
    else
        sharedataLib.new(SVRCONF_CONF_KEY_GATE_PVP, values)
    end
end

-- 获取战斗服gate配置(仅game服节点有该配置)
function initDBConf:getGatePvpConf(nodeid)
    return self:getConf(SVRCONF_CONF_KEY_GATE_PVP, nodeid)
end

-- 获取配置
function initDBConf:getConf(key, nodeid)
    if not self.sharedataRef then
        self.sharedataRef = {}
    end
    local ret = self.sharedataRef[key]
    if not ret then
        local sharedataLib = require("sharedataLib")
        ret = sharedataLib.query(key)
        self.sharedataRef[key] = ret
    end
    -- gLog.dump(ret, string.format("initDBConf:getConf key = %s, ret=", key), 10)
    if nodeid then
        if ret[nodeid] then
            return ret[nodeid]
        end
    else
        return ret
    end
end

-- 打印
function initDBConf:dump()
    gLog.i("====== initDBConf:dump begin======")
    local clusterConf = self:getClusterConf()
    local debugConf = self:getDebugConf()
    local httpConf = self:getHttpConf()
    local kingdomConf = self:getKingdomConf()
    local loginConf = self:getLoginConf()
    local globalConf = self:getGlobalConf()
    local gateConf = self:getGateConf()
    local noticeHttpConf = self:getNoticeHttpConf()
    local whiteListConf = self:getIpWhiteListConf()

    gLog.dump(clusterConf, "initDBConf:dump clusterConf", 10)
    gLog.dump(debugConf, "initDBConf:dump debugConf", 10)
    gLog.dump(httpConf, "initDBConf:dump httpConf", 10)
    gLog.dump(kingdomConf, "initDBConf:dump kingdomConf", 10)
    gLog.dump(loginConf, "initDBConf:dump loginConf", 10)
    gLog.dump(globalConf, "initDBConf:dump globalConf", 10)
    gLog.dump(gateConf, "initDBConf:dump gateConf", 10)
    gLog.dump(noticeHttpConf, "initDBConf:dump noticeHttpConf", 10)
    gLog.dump(whiteListConf, "initDBConf:dump whiteListConf", 10)

    gLog.i("====== initDBConf:dump end======")
end

return initDBConf

