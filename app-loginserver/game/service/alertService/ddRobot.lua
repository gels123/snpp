-- 钉钉机器人
local json = require("json")
local luacurl = require("luacurl")
local ddRobot = class("ddRobot")

function ddRobot:ctor(robotUrl)
	assert("string" == type(robotUrl))
	self.robotUrl = robotUrl
end

function ddRobot:pushText(text, isAtAll)
	if "string" ~= type(text) then
		return
	end
	local msg = {
		msgtype = "text",
		text = {
			content = text
		},
		at = {
			isAtAll = isAtAll
		}
	}
	self:sendMsg(msg)
end

function ddRobot:pushMD(title, text, isAtAll)
	local msg = {
		msgtype = "markdown",
		markdown = {
			title = title,
			text = text
		},
		--at = {
		--	isAtAll = isAtAll
		--}
	}
	self:sendMsg(msg)
end

function ddRobot:getCurl()
	return luacurl.easy()
end

function ddRobot:sendMsg(msg)
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
	curl:setopt(luacurl.OPT_WRITEFUNCTION,function (userparam, buffer)
		mybuffer = mybuffer .. buffer
		return string.len(buffer)
	end)
	local mywritedata = {}
	curl:setopt(luacurl.OPT_WRITEDATA,mywritedata)
	pcall(function()
		curl:perform()
	end)
	--gLog.d("ddRobot:sendMsg=", xpcallOk, ok, errmsg, errcode, mywritedata)
end

return ddRobot
