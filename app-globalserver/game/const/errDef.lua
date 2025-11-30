--[[
	错误码定义
]]
gErrDef =
{
	---- 公共错误码 ---->
	Err_OK = 0, -- 成功
	Err_SERVICE_EXCEPTION = 1, -- 服务器异常
	Err_CMD_NOT_FOUND = 2, -- 指令未找到
	Err_ILLEGAL_PARAMS = 3, -- 非法的参数
	Err_CMD_OPTING = 4, -- 指令正在处理中
	Err_ILLEGAL_STATUS = 5, -- 状态非法
	Err_NOT_DEBUG = 6, -- 非DEBUG环境, 直接失败
	Err_CANT_BE_SELF = 7, -- 目标不能是自己
	Err_COUNT_LIMIT = 8, -- 数量超过限制
	Err_NOT_SUPPORT_GAME_REQ = 9, -- 不支持处理来自game的请求

	---- 领主模块错误码 ---->
	Err_LORD_NOT_EXIST = 100, -- 领主不存在
	Err_LORD_CREATE_NPC_REPEAT = 101, -- 重复创角
	Err_LORD_CREATE_NPC_LIMIT = 102, -- npc数量达到上限
	Err_LORD_NPC_NOT_EXSIT = 103, -- 目标npc不存在
	Err_LORD_NPC_DELETE_DEFAULT = 104, -- 初始npc不能删除

	------背包/道具模块错误码------->
	Err_BACKPACK_TYPE = 200, -- 背包类型错误
	Err_ITEM_NOT_EXIST = 201, -- 物品不存在
	Err_BACKPACK_FULL = 202, -- 背包已满
	Err_ITEM_NOT_ENOUGH = 203, -- 道具不足

	------邮件模块错误码------->
	Err_MAIL_CREATE = 300,	--创建邮件失败
	Err_MAIL_NO_DATA = 301,	--邮件数据不存在
	Err_MAIL_NO_MORE = 302,	--没有更多邮件
	Err_MAIL_NOT_EXSIT = 303, --邮件不存在
	Err_MAIL_FULL_PACKAGE = 304, --背包已满不能领取附件
	Err_MAIL_COUNT_LIMIT = 305, --邮件数量达到上限
	Err_MAIL_COLLECT_EXTRA = 306, --邮件存在未领取的附件, 不能收藏

	---- 拍卖行错误码 ---->
	Err_TRADE_ERR = 400,					--拍卖行异常
	Err_TRADE_BUY_INVALID = 401,			--拍卖行购买验证失败
	Err_TRADE_GOODS_NOT_EXIST = 402,		--拍卖行物品不存在或已失效

	---- 聊天错误码 ---->
	Err_CHAT_AUTH_ERR = 500, --网关验证失败
	Err_CHAT_SEND_MSG_ERR = 501, --非聊天室成员, 不能发送聊天消息
	Err_CHAT_HAD_FRIEND = 502, --好友已存在
	Err_CHAT_HAD_APPLY = 503, --已在申请列表
	Err_CHAT_SELF_APPLY = 504, --添加好友的目标不能是自己
	Err_CHAT_NO_APPLY = 505, --好友申请不存在或已过期
	Err_CHAT_HAD_BLACKS = 506, --黑名单已存在
	Err_CHAT_NO_BLACKS = 507, --黑名单不存在
	Err_CHAT_IN_BLACKS = 509, --已被对方添加到黑名单
	Err_CHAT_FRIEND_LIMIT = 510, --对方好友数量已满
}

return gErrDef