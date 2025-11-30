--[[
    main函数
]]
local skynet = require("skynet")
local cluster = require("cluster")
local dbconf = require("dbconf")
local svrConf = require("svrConf")
local initDBConf = require("initDBConf")
local svrAddrMgr = require("svrAddrMgr")
local sharedataLib = require("sharedataLib")

skynet.start(function ()
    local ok = xpcall(function()
        print("====== main start begin =======")
        gLog.i("====== main start begin =======")
        -- 设置统一的随机种子
        math.randomseed(os.time())
        gLog.i("====== main start 0 =======")

        -- 报错信息推送服务
        skynet.newservice("alertService")
        gLog.i("====== main start 1 =======")

        -- 检查节点配置
        assert(dbconf.globalnodeid and not dbconf.loginnodeid)
        gLog.i("====== main start 2 =======")

        -- 配置数据DB服务
        if dbconf.dbtype == "mysql" then
            local address = skynet.newservice("mysqlService", "master", dbconf.mysql_confdb.instance)
            svrAddrMgr.setSvr(address, svrAddrMgr.confDBSvr)
            skynet.call(address, "lua", "connect", dbconf.mysql_confdb)
        elseif dbconf.dbtype == "mongodb" then
            local address = skynet.newservice("mongodbService", "master", dbconf.mongodb_confdb.instance)
            svrAddrMgr.setSvr(address, svrAddrMgr.confDBSvr)
            skynet.call(address, "lua", "connect", dbconf.mongodb_confdb)
        else
            assert(false, "dbconf.dbtype error"..tostring(dbconf.dbtype))
        end
        gLog.i("====== main start 3 =======")

        -- 游戏数据DB服务
        if dbconf.dbtype == "mysql" then
            local address = skynet.newservice("mysqlService", "master", dbconf.mysql_gamedb.instance)
            svrAddrMgr.setSvr(address, svrAddrMgr.gameDBSvr)
            skynet.call(address, "lua", "connect", dbconf.mysql_gamedb)
        elseif dbconf.dbtype == "mongodb" then
            local address = skynet.newservice("mongodbService", "master", dbconf.mongodb_gamedb.instance)
            svrAddrMgr.setSvr(address, svrAddrMgr.gameDBSvr)
            skynet.call(address, "lua", "connect", dbconf.mongodb_gamedb)
        else
            assert(false, "dbconf.dbtype error"..tostring(dbconf.dbtype))
        end
        gLog.i("====== main start 4 =======")

        -- 本地redis服务
        local redisSvr = skynet.newservice("redisService", "master", dbconf.redis.instance, "master")
        svrAddrMgr.setSvr(redisSvr, svrAddrMgr.redisSvr)
        skynet.call(redisSvr, "lua", "connect", dbconf.redis)
        gLog.i("====== main start 5 =======")

        -- 公共redis服务
        local redisSvr = skynet.newservice("redisService", "master", dbconf.publicRedis.instance, "master")
        svrAddrMgr.setSvr(redisSvr, svrAddrMgr.publicRedisSvr)
        skynet.call(redisSvr, "lua", "connect", dbconf.publicRedis)
        gLog.i("====== main start 6 =======")

        -- 加载服务器配置、刷库
        initDBConf:set()
        initDBConf:executeGlobalDataSql()
        gLog.i("====== main start 7 =======")

        -- 调试控制台服务
        skynet.newservice("debug_console", svrConf:debugConfGlobal(dbconf.globalnodeid).port)
        gLog.i("====== main start 8 ======= debugport=", svrConf:debugConfGlobal(dbconf.globalnodeid).port)

        -- 集群配置
        cluster.open(svrConf:clusterConfGlobal(dbconf.globalnodeid).listennodename)
        gLog.i("====== main start 9 =======")

        -- 启动服务
        skynet.newservice("serverStartService")
        gLog.i("====== main start 10 =======")

        -- 数据中心服务
        local playerDataLib = require("playerDataLib")
        for i = 1, playerDataLib.serviceNum do
            skynet.newservice("playerDataService", dbconf.globalnodeid, i)
        end
        gLog.i("====== main start 11 =======")

        -- 公共杂项服务
        local commonLib = require("commonLib")
        for i = 1, commonLib.serviceNum do
            skynet.newservice("commonService", dbconf.globalnodeid, i)
        end
        gLog.i("====== main start 12 =======")

        -- (可选)微服务网关服务
        skynet.newservice("gateService")
        gLog.i("====== main start 13 =======")

        -- 微服务agent
        local agentLib = require("agentLib")
        for i = 1, agentLib.serviceNum do
            skynet.newservice("agent", dbconf.globalnodeid, i)
        end
        gLog.i("====== main start 14 =======")

        -- 聊天服务
        local chatLib = require("chatLib")
        for i = 1, chatLib.serviceNum do
            skynet.newservice("chatService", dbconf.globalnodeid, i)
        end
        gLog.i("====== main start 15 =======")

        -- 联盟服务
        local allianceLib = require("allianceLib")
        for i = 1, allianceLib.serviceNum do
            skynet.newservice("allianceService", dbconf.globalnodeid, i)
        end
        gLog.i("====== main start 16 =======")

        -- 登录服刷新配置
        local loginConf = initDBConf:getLoginConf()
        for k,v in pairs(loginConf) do
            pcall(function()
                local r = string.trim(io.popen(string.format("echo ' ' | telnet %s %d", v.web ~= "127.0.0.1" and v.web ~= "localhost" and v.web or v.host, v.port)):read("*all") or "")
                if string.find(r, "Connected") then
                    local startSvr = svrConf:getSvrProxyLogin(v.nodeid, svrAddrMgr.startSvr)
                    skynet.send(startSvr, "lua", "reloadConf", dbconf.globalnodeid)
                end
            end)
        end
        -- 全局服刷新配置
        local globalConf = initDBConf:getGlobalConf()
        for k,v in pairs(globalConf) do
            if v.nodeid ~= dbconf.globalnodeid then
                pcall(function()
                    local r = string.trim(io.popen(string.format("echo ' ' | telnet %s %d", v.web ~= "127.0.0.1" and v.web ~= "localhost" and v.web or v.ip, v.port)):read("*all") or "")
                    if string.find(r, "Connected") then
                        local startSvr = svrConf:getSvrProxyGlobal(v.nodeid, svrAddrMgr.startSvr)
                        skynet.send(startSvr, "lua", "reloadConf", dbconf.globalnodeid)
                    end
                end)
            end
        end
        -- 游戏服刷新配置
        local kingdomConf = initDBConf:getKingdomConf()
        for k,v in pairs(kingdomConf) do
            pcall(function()
                local r = string.trim(io.popen(string.format("echo ' ' | telnet %s %d", v.web ~= "127.0.0.1" and v.web ~= "localhost" and v.web or v.ip, v.port)):read("*all") or "")
                if string.find(r, "Connected") then
                    local startSvr = svrConf:getSvrProxyGame2(v.nodeid, svrAddrMgr.getSvrName(svrAddrMgr.startSvrGame, v.kid))
                    skynet.send(startSvr, "lua", "reloadConf", dbconf.globalnodeid)
                end
            end)
        end
        gLog.i("====== main start 17 =======")

        -- 标记启动成功并生成文件
        if require("serverStartLib"):getIsOk() then
            gLog.i("====== main start success =======")
            local file = io.open('./.startsuccess_global', "w+")
            file:close()
            -- 退出
            skynet.exit()
        else
            -- 启动失败, 等待日志输出5s后杀进程
            gLog.i("====== main start failed =======")
            skynet.timeout(500, function()
                require("lextra").reset_singal_handler()
            end)
        end
    end, svrFunc.exception)
    
    -- 启动失败, 等待日志输出5s后杀进程
    if not ok then
        gLog.i("====== main start failed =======")
        skynet.timeout(500, function()
            require("lextra").reset_singal_handler()
        end)
    end
end)
