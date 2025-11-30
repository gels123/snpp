--[[
	聊天相关定义
]]

-- 聊天室释放时间
gChatRoomFreeTime = 2*3600

-- 聊天室有效时间
gChatRoomAliveTime = 30 * 86400

-- 聊天室类型定义
gChatRoomType =
{
	group = 0,		-- 私聊/组聊
	alliance = 1,	-- 联盟聊天
	kingdom = 2,	-- 王国聊天
}

-- 聊天消息类型定义
gChatMsgType =
{
	text = 1,		-- 文本
	image = 2,		-- 图片
	voice = 3,		-- 语音
	emoji = 4,		-- 表情
	racelamp = 5,	-- 跑马灯
}
gChatMsgType2 = table.reverse(gChatMsgType)

-- 玩家agent计时器类型
gChatTimerType = {
	free = "free",           --释放聊天室倒计时
}
