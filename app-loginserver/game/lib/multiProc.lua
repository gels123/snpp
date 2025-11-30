--[[
    并行执行任务(fork多个任务并行执行, 所有任务都执行结束则恢复执行, 任一失败则中断执行)
    例子:
        local multiProc = require("multiProc").new()
        multiProc:fork(function()
            skynet.sleep(100) -- do something
        end)
        multiProc:fork(function()
            skynet.sleep(500) -- do something
        end)
        multiProc:wait()
        print("continue excute") --实际花费5s
]]
local skynet = require("skynet")
local svrFunc = require("svrFunc")
local multiProc = class("multiProc")

function multiProc:ctor()
    self.co = coroutine.running()
    self.task = {}
    self.success = true --是否全部任务均成功
end

-- 添加并行任务
function multiProc:fork(f)
    assert(type(f) == "function")
    local taskco = nil
    taskco = skynet.fork(function()
        local ok = xpcall(f, svrFunc.exception)
        if not ok then
            self.success = false
        end
        self.task[taskco] = nil
        if not next(self.task) then
            skynet.wakeup(self.co)
        end
    end)
    if self.task[taskco] then
        gLog.e("multiProc:fork error")
    end
    self.task[taskco] = true
end

-- 等待所有任务执行结束
function multiProc:wait()
    if next(self.task) then
        skynet.wait(self.co)
        assert(self.success) --非全部任务均成功, 中断流程
    end
end

return multiProc