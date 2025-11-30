--[[
	聊天服务中心
]]
local skynet = require "skynet"
local dbconf = require "dbconf"
local serviceCenterBase = require("serviceCenterBase2")
local chatCenter = class("chatCenter", serviceCenterBase)

-- 初始化
function chatCenter:init(kid, idx)
	gLog.i("==chatCenter:init begin==", kid, idx)
	self.super.init(self, kid)

	-- 索引
	self.idx = idx
	-- 聊天室管理器
	self.chatMgr = require("chatMgr").new()
	-- 计时器管理器
	self.timerMgr = require("timerMgr").new(handler(self, self.timerCallback), self.myTimer)

    gLog.i("==chatCenter:init end==", kid, idx)
end

-- 创建聊天室
-- @tp => 聊天室类型
-- @members => 聊天室成员 { {uid=1201},{uid=1202}, }
-- @kid => 王国聊天的王国
function chatCenter:createRoom(roomId, tp, members, kid, aid)
	gLog.d("chatCenter:createRoom", roomId, tp, members, kid, aid)
	local chatRoom = self.chatMgr:getRoom(roomId)
	return chatRoom:createRoom(tp, members, kid, aid)
end

-- 删除聊天室
function chatCenter:deleteRoom(roomId)
	self.chatMgr:deleteRoom(roomId)
end

-- 发送聊天消息
-- @msg => 聊天消息 见sChatMsg结构 {uid=101, tp=gChatMsgType.text, txt = "hello", time=1683870000}
function chatCenter:chat(roomId, msg)
	local chatRoom = self.chatMgr:getRoom(roomId)
	return chatRoom:chat(msg)
end

-- 计时器回调
function chatCenter:timerCallback(data)
	if dbconf.DEBUG then
		gLog.d("chatCenter:timerCallback data=", table2string(data))
	end
	local roomId, timerType = data.id, data.timerType
	if self.timerMgr:hasTimer(roomId, timerType) then
		local chatRoom = self.chatMgr:getRoom(roomId, true)
		if chatRoom then
			if timerType == gChatTimerType.free then
				self.chatMgr:releaseRoom(roomId)
			else
				gLog.w("chatCenter:timerCallback ignore", roomId, timerType)
			end
		else
			gLog.w("chatCenter:timerCallback ignore", roomId, timerType)
		end
	end
	--gLog.dump(self, "chatCenter:timerCallback self=")
end

return chatCenter
