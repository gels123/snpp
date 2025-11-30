-- 微信机器人
local json = require("json")
local luacurl = require("luacurl")
local wxRobot = class("wxRobot")

function wxRobot:ctor(robotUrl)
	assert("string" == type(robotUrl))
	self.robotUrl = robotUrl
end

function wxRobot:pushText(text)
	if "string" ~= type(text) then
		return
	end
	local msg = {
		msgtype = "text",
		text = {
			content = text
		},
	}
	self:sendMsg(msg)
end

function wxRobot:pushMD(title, text)
	local msg = {
		msgtype = "markdown",
		markdown = {
			content = text
		},
	}
	self:sendMsg(msg)
end

function wxRobot:getCurl()
	return luacurl.easy()
end

function wxRobot:sendMsg(msg)
	local curl = self:getCurl()
	curl:setopt(luacurl.OPT_URL,self.robotUrl)
	curl:setopt(luacurl.OPT_NOSIGNAL,true)
	curl:setopt(luacurl.OPT_CONNECTTIMEOUT,3)
	curl:setopt(luacurl.OPT_TIMEOUT,3)
	curl:setopt(luacurl.OPT_POST,true)
	curl:setopt(luacurl.OPT_HTTPHEADER,"Content-Type:application/json;charset=UTF-8")
	curl:setopt(luacurl.OPT_SSL_VERIFYPEER,false) --https
	curl:setopt(luacurl.OPT_SSL_VERIFYHOST,0) --https
	curl:setopt(luacurl.OPT_POSTFIELDS,json.encode(msg))

	local mybuffer = ""
	curl:setopt(luacurl.OPT_WRITEFUNCTION,function ( userparam, buffer )
		mybuffer = mybuffer .. buffer
		return string.len(buffer)
	end)
	local mywritedata = {}
	curl:setopt(luacurl.OPT_WRITEDATA,mywritedata)
	local xpcallOk, ok, errmsg, errcode = xpcall(function()
		return curl:perform()
	end, svrFunc.exception)
	gLog.d("wxRobot:sendMsg=", xpcallOk, ok, errmsg, errcode, mywritedata)
end

return wxRobot
