--
-- letter 字母 不够成独立的意思
-- word 字 构成独立的意思
local WordFilter = class("WordFilter")

function WordFilter:ctor(replaceWord,ignoreWords,maxDepth)
	ignoreWords = ignoreWords or ""
	self.maxDepth = maxDepth or 20   --最大深度，暂未处理
	self.firstLevel = {_isInit=false,_isEnd=false,iters={},map={}}
	self.ignoreCode = {}


	for i,code in utf8.codes(ignoreWords) do
		self.ignoreCode[code] = true
	end

	self.replaceCode = utf8.codepoint(replaceWord)
end

function WordFilter:init(list, removeIgnoreWords)
	for k,words in pairs(list) do
		local iter = {}
		local formatWords
		if removeIgnoreWords then
			formatWords = ""
			for _, code in utf8.codes(words) do
				if not self.ignoreCode[code] then
					formatWords = table.concat({formatWords, utf8.char(code)})
				end
			end
		else
			formatWords = words
		end
		iter._f,iter._s,iter._var = utf8.codes(formatWords)
		local code = self:nextCode(iter)
		if code then
			if not self.firstLevel.map[code] then
				local nextLevel = {_isInit=false,_isEnd=false,iters={},map={}}
				self.firstLevel.map[code] = nextLevel
			end
			table.insert(self.firstLevel.map[code].iters,iter)
		end
	end
	self.firstLevel._isInit = true
end

function WordFilter:unfoldLevel(level,isAdd)
	if not level then
		return
	end
	--已经解析完成，直接返回
	if level._isInit and not isAdd then
		return
	end

	--解析该层，生成下一层
	for i,iter in ipairs(level.iters) do
		local code = self:nextCode(iter)
		if code then
			if not level.map[code] then
				local nextLevel = {_isInit=false,_isEnd=false,iters={},map={}}
				level.map[code] = nextLevel
				-- print("----unfold ",utf8.char(code))
			end
			table.insert(level.map[code].iters,iter)
		else
			level._isEnd = true
		end
	end
	level._isInit = true
	level.iters = {} --该层解析完成，清空
end


--对字母需要判断前后
function WordFilter:replaceLetters(codeList,replace,iter)
	--该词前面为字母,不为屏蔽词
	if self:isLetter(codeList[replace.beginIndex - 1]) then
		return nil
	end

	--多个屏蔽词相连，不用处理.由于前一个屏蔽词已被替换成*,*不为字母

	--该词继续往后拓
	local tempIter = {}
	self:copyIter(tempIter, iter)
	local currentLevel = replace.level
	local nextLevel = nil
	local tempList = {}
	local code = nil
	local hasNewLetter = false
	while true do
		code = self:nextCode(tempIter)
		if code then
			code = self:convertEnLowerCode(code)
			table.insert(tempList,code)
			if self:isLetter(code) and currentLevel then
				hasNewLetter = true
				nextLevel = currentLevel.map[code]
				currentLevel = nextLevel
				self:unfoldLevel(nextLevel)
				--最后字母构成屏蔽词
				print("--------replaceLetters code ",utf8.char(code),nextLevel and nextLevel._isEnd)
			else
				break
			end
		else
			break
		end
	end

	if nextLevel and nextLevel._isEnd then
		for i,v in ipairs(tempList) do
			table.insert(codeList,v)
		end
		replace.endIndex = #codeList
		self:copyIter(iter,tempIter)
	elseif hasNewLetter then
		return nil
	end

	return replace
end

function WordFilter:findEnd(iter,codeList)
	-- print("-----findEnd")
	local currentLevel = self.firstLevel
	local nextLevel = nil
	local tempList = {}
	local beginIndex = nil
	while true do
		local code = self:nextCode(iter)
		if code then
			code = self:convertEnLowerCode(code)
			table.insert(tempList,code)
			if not self.ignoreCode[code] then
				if not beginIndex then
					beginIndex = #codeList + #tempList
				end
				nextLevel = currentLevel.map[code]
				self:unfoldLevel(nextLevel)
				-- print("--------code ",utf8.char(code),nextLevel and nextLevel._isEnd)
				if nextLevel then
					if nextLevel._isEnd then
						local replace = {}
						replace.beginIndex = beginIndex
						for i,v in ipairs(tempList) do
							table.insert(codeList,v)
						end
						replace.endIndex = #codeList
						replace.level = nextLevel
						return replace
					end
					currentLevel = nextLevel
				else
					table.insert(codeList,tempList[1]) --未找到，则添加头部
					return nil
				end
			end
		else
			for i,v in ipairs(tempList) do
				table.insert(codeList,v)
			end
			return nil
		end
	end
end

function WordFilter:findReplace(iter,codeList)
	local replace
	local tempIter = {}
	while true do
		self:copyIter(tempIter, iter)
		local code = self:nextCode(iter)
		if code then
			replace = self:findEnd(tempIter,codeList) --尝试寻找最后一个屏蔽字
			--找到则结束，否则继续遍历
			if replace then
				self:copyIter(iter, tempIter)
				return replace
			end
		else
			return nil --遍历完成
		end
	end
end


function WordFilter:doFilter(words)
	local codeList = {}
	local filterWordList = {}
	local iter = {}
	local beReplaced = false
	iter._f,iter._s,iter._var = utf8.codes(words)

	while true do
		local replace = self:findReplace(iter,codeList)
		if replace then
			print("--------replace ",replace.beginIndex,replace.endIndex)
			if self:isLetter(codeList[replace.endIndex]) then
				replace = self:replaceLetters(codeList,replace,iter)
			end
			if replace then
				beReplaced = true
				local filterWord = {}
				for i=replace.beginIndex,replace.endIndex do
					filterWord[i - replace.beginIndex + 1] = codeList[i]
					codeList[i] = self.replaceCode
				end
				table.insert(filterWordList, utf8.char(table.unpack(filterWord)))
			end
		else
			break
		end
	end

	if beReplaced then
		return utf8.char(table.unpack(codeList)), filterWordList
	else
		return nil
	end
end

function WordFilter:isFilter(words)
	local codeList = {}
	local iter = {}
	local beReplaced = false
	iter._f,iter._s,iter._var = utf8.codes(words)

	while true do
		local replace = self:findReplace(iter,codeList)
		local nextReplace = self:findReplace(iter,codeList)
		if replace then
			if self:isLetter(codeList[replace.endIndex]) then
				replace = self:replaceLetters(codeList,replace,iter)
			end
			if replace then
				return true  --遇到屏蔽词就返回
			end
		else
			return false
		end
	end
end

function WordFilter:nextCode(iter)
	local k,v = iter._f(iter._s,iter._var)
	if k then
		iter._var = k
	end
	return v
end

function WordFilter:isLetter(code)
	if not code then
		return false
	end

	local letterArea = {65,90,97,122,126,687,880,1791,3584,3711}
	local len = #letterArea
	for i=1,len,2 do
		if code >= letterArea[i] and code <= letterArea[i+1] then
			return true
		end
	end

	return false
end

function WordFilter:convertEnLowerCode(code)
	if code >= 65 and code <=90 then
		return code + 32
	end
	return code
end


function WordFilter:addFilterWord(words, removeIgnoreWords)
	if not words then
		return
	end
	--第一层增加屏蔽词
	self:init({words}, removeIgnoreWords)

	local currLevel = self.firstLevel
	local nextLevel = currLevel
	--展开其他层
	for index,code in utf8.codes(words) do
		if not self.ignoreCode[code] then
			code = self:convertEnLowerCode(code)
			nextLevel = currLevel and currLevel.map[code]
			if nextLevel then
				self:unfoldLevel(nextLevel,true) --对于已经展开过的，强制再展开一遍
				currLevel = nextLevel
			end
		end
	end
end

--删除屏蔽词，直接删掉最后一层(理论上可以向前回溯，进行删除剪枝，暂不这么做)
function WordFilter:delFilterWord(words)
	if not words then
		return
	end

	local currLevel = self.firstLevel
	local nextLevel = currLevel
	local notFind = false

	for index,code in utf8.codes(words) do
		if not self.ignoreCode[code] then
			code = self:convertEnLowerCode(code)
			nextLevel = currLevel and currLevel.map[code]
			if nextLevel then
				self:unfoldLevel(nextLevel) --被删除的该词，可能还未展开，先展开下
				currLevel = nextLevel
			else
				notFind = true
			end
		end
	end

	if notFind then
		print("----------not find del words",words)
	else
		nextLevel._isEnd = false --删除最后一层
	end
end

function WordFilter:copyIter(dst,src)
	dst._f,dst._s,dst._var = src._f,src._s,src._var
	return dst
end

return WordFilter