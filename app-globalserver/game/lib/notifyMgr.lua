--[[
	Description:
		事件推送，用于一个服务间或不同服务之间。借助了 quick 的 EventProtocol 组件来管理事件。
		1.同一个服务：完全使用 EventProtocol 组件，用法也是完全相同的。
		2.跨服务：举个例子，A服务监听B服务。A服务向B服务注册时，要将回调时调用的 cmd 名称发给B服务：
			skynet.call(B, "lua", "addServiceEventListener", eventName, rspCmd)

		而，B服务收到注册消息时，生成一个闭合函数，并以此作为 EventProtocol 组件的事件回调：

			-- 跨服务注册单个事件
			function notifyMgr:addServiceEventListener( source, eventName, rspCmd )
				gLog.i("跨服务事件注册:", eventName, rspCmd)
				-- EventProtocol 组件的事件回调闭合函数
				local function serviceListener( event )
					local retdata = {}
					retdata.name = event.name
					retdata.data = event.data
					skynet.send(source, "lua", rspCmd, retdata)
				end
				return self:addEventListener(eventName, serviceListener)
			end

--]]

local skynet = require("skynet")
local notifyMgr = class("notifyMgr", cc.mvc.ModelBase)

local instance = nil

-- 获取单例
function notifyMgr.sharedInstance()
	if not instance then
		instance = notifyMgr.new()
	end

	return instance
end

-- 构造
function notifyMgr:ctor()
	notifyMgr.super.ctor(self)
end

-- 跨服务注册单个事件
function notifyMgr:addServiceEventListener(source, eventName, rspCmd)
	--[[print(string.format("服务 %s 向服务 %s 注册监听事件, eventName = %s, rspCmd = %s",
		skynet.address(source),
		skynet.address(skynet.self()),
		eventName,
		rspCmd
	))]]
	
	-- EventProtocol 组件的事件回调闭合函数
	local function serviceListener(event)
		local retdata = {}
		retdata.name = event.name
		retdata.data = event.data
		skynet.send(source, "lua", rspCmd, retdata)
	end
	return self:addEventListener(eventName, serviceListener)
end

-- 跨服务事件移除，根据 handle
function notifyMgr:removeServiceEventListener(source, handle)
	--[[print(string.format("服务 %s 删除在服务 %s 的监听，handle = %s",
		skynet.address(source),
		skynet.address(skynet.self()),
		handle
	))]]
	self:removeEventListener(handle)
	return true
end

-- 跨服务事件移除，根据 eventName
function notifyMgr:removeServiceEventListenerByEvent(source, eventName)
	--[[print(string.format("服务 %s 删除在服务 %s 的监听，eventName = %s",
		skynet.address(source),
		skynet.address(skynet.self()),
		eventName
	))]]
	
	self:removeEventListenersByEvent(eventName)
	return true
end


-- 推送事件
--[[
	eventName：事件名
	data：数据
	监听者收到的event
	event = {
		name = eventName,
		data = data,
		...
	}
--]]
function notifyMgr:notify( eventName, data)
	-- 推送本地
	self:dispatch_(eventName, data)
end

-- 推送给客户端(仅供非 agentlt 服务使用)
function notifyMgr:notifyClient(notifyID, notifyData, uid, kingdomID)
    if uid and notifyID and notifyData then
    	local kingdomID = kingdomID or gKingdomID
        -- 推送
        notifyData = notifyData or {}
        if next(notifyData) then
        	local playerAgent = include("playerAgent").new(kingdomID, uid)
        	playerAgent:notifyClient(notifyID, notifyData)
        end
    end
end

-- 分发事件
function notifyMgr:dispatch_( eventName, data )
	local event = {}
	event.name = eventName
	event.data = data
	self:dispatchEvent(event)
end

return notifyMgr
