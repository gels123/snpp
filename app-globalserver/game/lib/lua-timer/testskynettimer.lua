local skynet = require("skynet")
local timer = require("skynetimer").new()
timer:start()

local timeout =  function( parm )
	gLog.i("timeout ===",parm,math.floor(skynet.time()))
end
local curtime = math.floor(skynet.time())
gLog.i("create time =",math.floor(skynet.time()))
local tid = timer:add(600,timeout,"success")
-- timer:add(6,timeout,3)
-- timer:delete(1)
-- timer:stop()

-- 测试暂停/恢复
-- timer:pause()
-- skynet.timeout(700,function()
-- 	gLog.i("resume ===")
-- 	timer:resume()
-- end)

-- 测试重新设置计时器
skynet.sleep(300)
local newtid = timer:reset(tid,100)
gLog.i("newtid == ",newtid)


--性能测试
--性能测试数据
--2020-06-15 15:11:38 1592205098.16 [INFO] :00000008 main [main.lua:48] t1 =  0.922298
--2020-06-15 15:11:41 1592205101.54 [INFO] :00000008 main [main.lua:53] t2 =  3.416354

local timer = require("skynetimer").new()
timer:start()

local Timer = require("timer").new()
Timer:start()
local curtime = os.time()
local func = function(param)

end
local count = 1000000
local t1 = os.clock()
for i = 1, count do
	local tid = timer:add(10000,func)
	if i == 500000 then
		gLog.i("delete")
		timer:delete(tid)
	end
end
local t2 = os.clock()
gLog.i("t1 = ",t2 - t1)
for i = 1, count do
	Timer:schedule(func,curtime+100)
	if i == 500000 then
		gLog.i("delete1")
		timer:stop(tid)
	end
end
local t3 = os.clock()
gLog.i("t2 = ",t3 - t2)


