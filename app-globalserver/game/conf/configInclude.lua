--[[
    配置文件路径
--]]
local CURRENT_MODULE_NAME = ...

-- lua 文件索引名称，具体路径
local fileName2Path = {
    -- constDefInit = "constDef.init",
}

-- 全局函数include, 加载文件
function include(name)
    local path = fileName2Path[name]
    if path then
        return import(path)
    else
        return import(name)
    end
end

function getfullname(name)
    return fileName2Path[name]
end