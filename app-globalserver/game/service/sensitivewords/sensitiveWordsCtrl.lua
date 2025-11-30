--[[
	敏感字过滤
]]
local dbconf = require("dbconf")
local WordFilter = require("WordFilter")
local sensitiveWordsCtrl = class("sensitiveWordsCtrl")

function sensitiveWordsCtrl:ctor()
    self:init()
end

-- 获取单例
function sensitiveWordsCtrl:sharedInstance()
    if not self.instance then
        self.instance = self.new()
    end

    return self.instance
end

-- 初始化
function sensitiveWordsCtrl:init()
	self.chatFilter = WordFilter.new("*","* +-[].,~/!@#$%^&():'\"\\<>_。，：——《》？?！￥{}|;、·`=\n")
	self.nameFilter = WordFilter.new("*","* +-[].,~/!@#$%^&():'\"\\<>_。，：——《》？?！￥{}|;、·`=\n")
	
	local function createShieldConfig(localtb, ret)
		ret = ret or {}
		for k, v in pairs(localtb) do
			ret[k] = v
	    end
	end

	self.shieldedWordsSplit = {}
	self.shieldedNameSplit = {}

	-- 屏蔽词
	local shieldedWords = require("local_shieldedwords")
	createShieldConfig(shieldedWords, self.shieldedWordsSplit)

	-- 名称屏蔽词
	local shieldedName = require("local_shieldedname")
    createShieldConfig(shieldedName, self.shieldedNameSplit)

	self.chatFilter:init(self.shieldedWordsSplit)
	self.nameFilter:init(self.shieldedNameSplit)

end

-- 是否有屏蔽字 return true or false
function sensitiveWordsCtrl:hasShieldedWord( words )
	if "string" ~= type(words) or "" == words then
		printError("sensitiveWordsCtrl.checkShieldedWords: words = %s", tostring(words))
		return
	end
	local hasFlag = self.chatFilter:isFilter(words)
	return hasFlag 
end


-- 名字是否有屏蔽词
function sensitiveWordsCtrl:isNameShieldWord( words )
	if "string" ~= type(words) or "" == words then
		printError("sensitiveWordsCtrl.checkShieldedWords: words = %s", tostring(words))
		return false
	end
	local hasFlag = self.nameFilter:isFilter(words)
	if not hasFlag then
		hasFlag = self.chatFilter:isFilter(words)
	end
	return hasFlag
end

-- 是否是阿拉伯字母
function sensitiveWordsCtrl:isArabAlphabet( str )
	if "string" ~= type(str) or "" == str then
		printError("sensitiveWordsCtrl.checkShieldedWords: words = %s", tostring(str))
		return
	end

	if #str == 2 then
		if 0xd8 <= string.byte(str, 1) and string.byte(str, 1) <= 0xdb and
			0x80 <= string.byte(str, 2) and string.byte(str, 2) <= 0xbf then
			return true
		end
	end

	return false
end

-- 是否是英文字母
function sensitiveWordsCtrl:isEnAlphabet( str )
	if "string" ~= type(str) or "" == str then
		printError("sensitiveWordsCtrl.checkShieldedWords: words = %s", tostring(str))
		return
	end

	if string.match(str, "%a") then
		return true
	end

	return false
end

-- 是否是字母
function sensitiveWordsCtrl:isAlphabet( str )
	if "string" ~= type(str) or "" == str then
		printError("sensitiveWordsCtrl.checkShieldedWords: words = %s", tostring(str))
		return
	end

	if self:isEnAlphabet(str) or self:isArabAlphabet(str) then
		return true
	end

	return false
end

-- 字符是否合法
function sensitiveWordsCtrl:isChatLegality( c )
	if not dbconf.gameType or dbconf.gameType == gGameType.koh then
		if not dbconf.areaType or gServerAreaType.arab == dbconf.areaType then
			return self:isAlphabet(c)
		elseif gServerAreaType.west == dbconf.areaType then
			return (" " ~= c)
		end
	else
		return (" " ~= c)
	end
end

-- 用*替换屏蔽字
-- return 用*替换敏感字后的字符串
function sensitiveWordsCtrl:replaceShieldedWords( strContent, language )
	if "string" ~= type(strContent) or "" == strContent then
		printError("sensitiveWordsCtrl.checkShieldedWords: words = %s", tostring(strContent))
		return "",false
	end

	local replaceword = self.chatFilter:doFilter(strContent)
	if replaceword then
		return replaceword,true
	else
		return strContent,false
	end
end

-- 角色名是否合法
function sensitiveWordsCtrl:isNameLegality( words )
	if "string" ~= type(words) or "" == words then
		printError("sensitiveWordsCtrl.isNameLegality: words = %s", tostring(words))
		return
	end

	if string.match(words, "%s%s+") then
		return false
	end

	local wordArray = serviceFunctions.convertStringToArray(words)
	local n = #wordArray

	for i, v in ipairs(wordArray) do
		if not dbconf.gameType or dbconf.gameType == gGameType.koh then
			if not dbconf.areaType or gServerAreaType.arab == dbconf.areaType then
				if not self:isAlphabet(v) and not string.match(v, "%d") and " " ~= v then
					return false
				end
			elseif gServerAreaType.west == dbconf.areaType then
				if not self:isEnAlphabet(v) and not string.match(v, "%d") and " " ~= v then
					return false
				end
			end
		else
			if not self:isEnAlphabet(v) and not self:isAlphabet(v) and not string.match(v, "%d") and " " ~= v then
				return false
			end
		end
	end

	return true
end

-- 是否合法,包含英文数字及阿语
function sensitiveWordsCtrl:isSearchNameLegality( str )
  if "string" ~= type(str) or "" == str then
    printError("sensitiveWordsCtrl.checkShieldedWords: words = %s", tostring(str))
    return false
  end
  return string.match(str, "%w")
end

return sensitiveWordsCtrl