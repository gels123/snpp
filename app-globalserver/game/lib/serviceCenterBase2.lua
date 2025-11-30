--[[
    服务中心基类(使用新版计时器)
    Created by Gels on 2021/8/26.
]]
local skynet = require("skynet")
local mc = require("skynet.multicast")
local skynetQueue = require("skynet.queue")
local svrFunc = require("svrFunc")
local serviceCenterBase = class("serviceCenterBase")

-- 获取单例
local instance = nil
function serviceCenterBase.shareInstance(cc)
    if not instance then
        instance = cc.new()
    end
    return instance
end

-- 构造函数
function serviceCenterBase:ctor()
    -- 王国ID
    self.kid = nil
    -- 计时器
    self.myTimer = nil
    -- 开始频道
    self.startChannel = nil
    -- 串行队列
    self.sq = {}
    -- 是否停服中
    self.stoping = false
    -- 是否已停服
    self.stoped = false
end

-- 初始化
function serviceCenterBase:init(kid)
    gLog.i("== serviceCenterBase:init begin ==", kid, self.class.__cname)
    -- 初始化王国ID
    self.kid = tonumber(kid)
    -- 初始化计时器
    self.myTimer = require("scheduler2").new()
    -- 订阅服务器启动服务频道
    self:subscribeStartService()
    gLog.i("== serviceCenterBase:init end ==", kid, self.class.__cname)
end

-- 获取王国ID
function serviceCenterBase:getKid()
    return self.kid
end

-- 获取定时器模块实例
function serviceCenterBase:getTimer()
    return self.myTimer
end

-- 获取是否已停服
function serviceCenterBase:getStoped()
    return self.stoped
end

-- 订阅服务器启动服务频道
function serviceCenterBase:subscribeStartService()
    local startSvr = svrAddrMgr.getSvr(svrAddrMgr.startSvr, self.kid)
    local channelID = skynet.call(startSvr, "lua", "getChannel")
    if channelID then
        self.startChannel = mc.new({
            channel = channelID,
            dispatch = function (channel, source, ...)
                self.startChannel:unsubscribe()
                self:start()
            end
        })
        self.startChannel:subscribe()
    end
end

-- 开始服务
function serviceCenterBase:start()
    gLog.i("== serviceCenterBase:start begin ==", self.kid, self.class.__cname)
    if self.myTimer then
        self.myTimer:start()
    end
    gLog.i("== serviceCenterBase:start end ==", self.kid, self.class.__cname)
end

-- 停止服务
function serviceCenterBase:stop()
    gLog.i("== serviceCenterBase:stop begin ==", self.kid, self.class.__cname)
    -- 标记停服中
    if self.stoping then
        return
    end
    self.stoping = true
    -- 标记已停服
    self.stoped = true
    if self.myTimer then
        self.myTimer:pause()
    end
    gLog.i("== serviceCenterBase:stop end ==", self.kid, self.class.__cname)
end

-- 杀死服务
function serviceCenterBase:kill()
    gLog.i("== serviceCenterBase:kill begin ==", self.kid, self.class.__cname)
    self:stop()
    skynet.exit() -- skynet.kill(skynet.self())
    gLog.i("== serviceCenterBase:kill begin ==", self.kid, self.class.__cname)
end

-- 分发服务端调用
function serviceCenterBase:dispatchCmd(session, source, cmd, ...)
    -- gLog.d("serviceCenterBase:dispatchCmd", session, source, cmd, ...)
    local f = instance and instance[cmd]
    if f then
        if 0 == session then
            xpcall(f, svrFunc.exception, self, ...)
        else
            self:ret(xpcall(f, svrFunc.exception, self, ...))
        end
    else
        if 0 ~= session then
            self:ret()
        end
        gLog.e("serviceCenterBase:dispatchCmd error: cmd not found:", cmd, ...)
    end
end

-- 返回数据
function serviceCenterBase:ret(ok, ...)
    if ok then
        skynet.ret(skynet.pack(...))
    else
        skynet.ret(skynet.pack())
    end
end

-- 获取串行队列
function serviceCenterBase:getSq(id)
    if not self.myTimer then
        self.myTimer = require("scheduler2").new()
        self.myTimer:start()
    end
    if not self.sqMgr then
	    self.sqMgr = require("timerMgr").new(function (t)
            self:delSq(t.id)
        end, self.myTimer)
    end
    local sq = self.sq[id]
    if not sq then
        sq = skynetQueue()
        self.sq[id] = sq
    end
    self.sqMgr:updateTimer(id, 0, svrFunc.systemTime()+180)
    return sq
end

-- 删除串行队列
function serviceCenterBase:delSq(id)
    -- gLog.d("serviceCenterBase:delSq", self.class.__cname, id, self.sq[id])
    if self.sq[id] then
        self.sq[id] = nil
        self.sqMgr:removeTimer(id, 0)
    end
end

return serviceCenterBase