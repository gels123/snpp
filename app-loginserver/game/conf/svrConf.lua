local skynet = require("skynet")
local cluster = require("cluster")
local dbconf = require("dbconf")
local initDBConf = require("initDBConf")
local svrConf = class("svrConf")

-- 获取跨节点服务代理
function svrConf:getSvrProxy(nodeid, svrName)
    -- gLog.d("svrConf:getSvrProxy", nodeid, svrName)
    local clusterConf = initDBConf:getClusterConf(nodeid)
    return cluster.proxy(clusterConf.nodename, svrName)
end

-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> login服节点相关配置 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- 获取login服节点的cluster配置
function svrConf:clusterConfLogin(nodeid)
    if not nodeid then
        local ret = initDBConf:getClusterConf()
        for k, v in pairs(ret) do
            if v.type == 1 then --cluster集群类型: 1登陆服 2全局服 3游戏服
                nodeid = v.nodeid
                break
            end
        end
    end
    assert(nodeid)
    return initDBConf:getClusterConf(nodeid)
end

-- 获取login服节点的debug配置
function svrConf:debugConfLogin(nodeid)
    if not nodeid then
        local ret = initDBConf:getClusterConf()
        for k, v in pairs(ret) do
            if v.type == 1 then --cluster集群类型: 1登陆服 2全局服 3游戏服
                nodeid = v.nodeid
                break
            end
        end
    end
    assert(nodeid)
    return initDBConf:getDebugConf(nodeid)
end

-- 获取login服节点的login配置(仅login服节点有该配置)
function svrConf:loginConfLogin(nodeid)
    if not nodeid then
        local ret = initDBConf:getClusterConf()
        for k, v in pairs(ret) do
            if v.type == 1 then --cluster集群类型: 1登陆服 2全局服 3游戏服
                nodeid = v.nodeid
                break
            end
        end
    end
    assert(nodeid)
    return initDBConf:getLoginConf(nodeid)
end

-- 获取login服节点的http配置
function svrConf:httpConfLogin(nodeid)
    if not nodeid then
        local ret = initDBConf:getClusterConf()
        for k, v in pairs(ret) do
            if v.type == 1 then --cluster集群类型: 1登陆服 2全局服 3游戏服
                nodeid = v.nodeid
                break
            end
        end
    end
    assert(nodeid)
    return initDBConf:getHttpConf(nodeid)
end

-- 获取login服节点的服务代理
function svrConf:getSvrProxyLogin(nodeid, svrName)
    if not nodeid then
        local ret = initDBConf:getClusterConf()
        for k, v in pairs(ret) do
            if v.type == 1 then --cluster集群类型: 1登陆服 2全局服 3游戏服
                nodeid = v.nodeid
                break
            end
        end
    end
    assert(nodeid)
    return self:getSvrProxy(nodeid, svrName)
end
--<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< login服节点相关配置 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> global服节点相关配置 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- 获取global服节点的cluster配置
function svrConf:clusterConfGlobal(nodeid)
    if not nodeid then
        local ret = initDBConf:getClusterConf()
        for k, v in pairs(ret) do
            if v.type == 2 then --cluster集群类型: 1登陆服 2全局服 3游戏服
                nodeid = v.nodeid
                break
            end
        end
    end
    assert(nodeid)
    return initDBConf:getClusterConf(nodeid)
end

-- 获取global服节点的debug配置
function svrConf:debugConfGlobal(nodeid)
    if not nodeid then
        local ret = initDBConf:getClusterConf()
        for k, v in pairs(ret) do
            if v.type == 2 then --cluster集群类型: 1登陆服 2全局服 3游戏服
                nodeid = v.nodeid
                break
            end
        end
    end
    assert(nodeid)
    return initDBConf:getDebugConf(nodeid)
end

-- 获取global服节点的http配置
function svrConf:httpConfGlobal(nodeid)
    if not nodeid then
        local ret = initDBConf:getClusterConf()
        for k, v in pairs(ret) do
            if v.type == 2 then --cluster集群类型: 1登陆服 2全局服 3游戏服
                nodeid = v.nodeid
                break
            end
        end
    end
    assert(nodeid)
    return initDBConf:getHttpConf(nodeid)
end

-- 获取global服节点的服务代理
function svrConf:getSvrProxyGlobal(nodeid, svrName)
    if not nodeid then
        local ret = initDBConf:getClusterConf()
        for k, v in pairs(ret) do
            if v.type == 2 then --cluster集群类型: 1登陆服 2全局服 3游戏服
                nodeid = v.nodeid
                break
            end
        end
    end
    assert(nodeid)
    return self:getSvrProxy(nodeid, svrName)
end
--<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< global服节点相关配置 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<


-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> game服节点相关配置 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
-- 获取game服节点的cluster配置
function svrConf:clusterConfGame(nodeid)
    if not nodeid then
        nodeid = dbconf.gamenodeid
    end
    assert(nodeid)
    return initDBConf:getClusterConf(nodeid)
end

-- 获取game服节点的debug配置
function svrConf:debugConfGame(nodeid)
    if not nodeid then
        nodeid = dbconf.gamenodeid
    end
    assert(nodeid)
    return initDBConf:getDebugConf(nodeid)
end

-- 获取game服节点的gate配置(仅game服节点有该配置)
function svrConf:gateConfGame(nodeid)
    if not nodeid then
        nodeid = dbconf.gamenodeid
    end
    assert(nodeid)
    return initDBConf:getGateConf(nodeid)
end

-- 根据王国ID获取王国配置信息
function svrConf:getKingdomConfByKid(kid)
    local kingdomConf = initDBConf:getKingdomConf()
    return kingdomConf[tonumber(kid)]
end

-- 根据节点ID获取该节点下的王国ID列表
function svrConf:getKingdomIDListByNodeID(nodeid)
    local kidList = {}
    local kingdomConf = initDBConf:getKingdomConf()
    for k,v in pairs(kingdomConf) do
        if tonumber(nodeid) == v.nodeid then
            table.insert(kidList, v.kid)
        end
    end
    return kidList
end

-- 获取game服节点的http配置
function svrConf:httpConfGame(nodeid)
    if not nodeid then
        nodeid = dbconf.gamenodeid
    end
    assert(nodeid)
    return initDBConf:getHttpConf(nodeid)
end

-- 获取game服节点的ip白名单配置
function svrConf:getIpWhiteListConfGame(kid)
    local conf = self:getKingdomConfByKid(kid)
    if conf then
        return initDBConf:getIpWhiteListConf(conf.nodeid)
    end
end

-- 获取game服节点的gate配置(仅game服节点有该配置)
function svrConf:getGatePvpConf(nodeid)
    if not nodeid then
        nodeid = dbconf.gamenodeid
    end
    assert(nodeid)
    return initDBConf:getGatePvpConf(nodeid)
end

-- 获取game服节点的服务代理
function svrConf:getSvrProxyGame(kid, svrName)
    local conf = self:getKingdomConfByKid(kid)
    if conf then
        return self:getSvrProxy(conf.nodeid, svrName)
    end
end

-- 获取game服节点的服务代理
function svrConf:getSvrProxyGame2(nodeid, svrName)
    assert(nodeid)
    return self:getSvrProxy(nodeid, svrName)
end
--<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< game服节点相关配置 <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

return svrConf

