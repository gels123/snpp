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
        print("====== main start begin =======", dbconf.loginnodeid)
        gLog.i("====== main start begin =======", dbconf.loginnodeid)

        -- 设置统一的随机种子
        math.randomseed(os.time())
        gLog.i("====== main start 1 =======")

        -- 报错信息推送服务
        skynet.newservice("alertService")
        gLog.i("====== main start 2 =======")

        -- 检查节点配置
        assert(dbconf.loginnodeid and not dbconf.gamenodeid and not dbconf.globalnodeid)
        gLog.i("====== main start 3 =======")

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
        gLog.i("====== main start 4 =======")

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
        gLog.i("====== main start 5 =======")

        -- 本地redis服务
        local address = skynet.newservice("redisService", "master", dbconf.redis.instance, "master")
        svrAddrMgr.setSvr(address, svrAddrMgr.redisSvr)
        skynet.call(address, "lua", "connect", dbconf.redis)
        gLog.i("====== main start 6 =======")

        -- 公共redis服务
        local address = skynet.newservice("redisService", "master", dbconf.publicRedis.instance, "master")
        svrAddrMgr.setSvr(address, svrAddrMgr.publicRedisSvr)
        skynet.call(address, "lua", "connect", dbconf.publicRedis)
        gLog.i("====== main start 7 =======")

        -- 加载服务器配置
        initDBConf:set()
        gLog.i("====== main start 8 =======")

        -- 调试控制台服务
        skynet.newservice("debug_console", svrConf:debugConfLogin(dbconf.loginnodeid).port)
        gLog.i("====== main start 9 =======debug console=", svrConf:debugConfLogin(dbconf.loginnodeid).port)

        -- 启动服务
        skynet.newservice("serverStartService")
        gLog.i("====== main start 10 =======")

        -- 启动http服务
        skynet.newservice("webService")
        gLog.i("====== main start 11 =======")

        --启动login服务
        skynet.newservice("loginService", "master")
        gLog.i("====== main start 12 =======")

        -- 集群配置
        cluster.open(svrConf:clusterConfLogin(dbconf.loginnodeid).listennodename)
        gLog.i("====== main start 13 =======")

        -- 登录服刷新配置
        local loginConf = initDBConf:getLoginConf()
        for k,v in pairs(loginConf) do
            if v.nodeid ~= dbconf.loginnodeid then
                xpcall(function()
                    local r = string.trim(io.popen(string.format("echo ' ' | telnet %s %d", v.web ~= "127.0.0.1" and v.web ~= "localhost" and v.web or v.host, v.port)):read("*all") or "")
                    if string.find(r, "Connected") then
                        local startSvr = svrConf:getSvrProxyLogin(v.nodeid, svrAddrMgr.startSvr)
                        skynet.send(startSvr, "lua", "reloadConf", dbconf.loginnodeid)
                    end
                end, debug.traceback)
            end
        end
        -- 全局服刷新配置
        local globalConf = initDBConf:getGlobalConf()
        for k,v in pairs(globalConf) do
            xpcall(function()
                local cmd = string.format("echo ' ' | telnet %s %d", v.web ~= "127.0.0.1" and v.web ~= "localhost" and v.web or v.ip, v.port)
                local r = string.trim(io.popen(string.format("echo ' ' | telnet %s %d", v.web ~= "127.0.0.1" and v.web ~= "localhost" and v.web or v.ip, v.port)):read("*all") or "")
                if string.find(r, "Connected") then
                    local startSvr = svrConf:getSvrProxyGlobal(v.nodeid, svrAddrMgr.startSvr)
                    skynet.send(startSvr, "lua", "reloadConf", dbconf.loginnodeid)
                end
            end, debug.traceback)
        end
        -- 游戏服刷新配置
        local kingdomConf = initDBConf:getKingdomConf()
        for k,v in pairs(kingdomConf) do
            xpcall(function()
                local r = string.trim(io.popen(string.format("echo ' ' | telnet %s %d", v.web ~= "127.0.0.1" and v.web ~= "localhost" and v.web or v.ip, v.port)):read("*all") or "")
                if string.find(r, "Connected") then
                    local startSvr = svrConf:getSvrProxyGame2(v.nodeid, svrAddrMgr.getSvrName(svrAddrMgr.startSvrGame, v.kid))
                    skynet.send(startSvr, "lua", "reloadConf", dbconf.loginnodeid)
                end
            end, debug.traceback)
        end
        gLog.i("====== main start 14 =======")

        -- 标记启动成功并生成文件
        if require("serverStartLib"):getIsOk() then
            gLog.i("=====start login service success=====", dbconf.loginnodeid, require("json").encode({[1]={a=1},[5]={b=2}}))
            local file = io.open('./.startsuccess_login', "w+")
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
