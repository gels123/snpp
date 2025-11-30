--[[
    json库
]]
local cjson = require("cjson.safe")
cjson.encode_sparse_array(true, 1, 1) --设置支持非标准json(稀疏数组)

local json = {}

function json.encode(var)
    local status, result = pcall(cjson.encode, var)
    if status then 
		return result 
	end
end

function json.decode(text)
    local status, result = pcall(cjson.decode, text)
    if status then 
		return result
	end
end

return json
