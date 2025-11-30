--------------------------------
-- @module functions
--[[--
提供一组常用函数，以及对 Lua 标准库的扩展
]]

--[[--
输出格式化字符串
]]
function printf(fmt, ...)
    print(string.format(tostring(fmt), ...))
end

--[[--
检查并尝试转换为数值，如果无法转换则返回 0
@param mixed value 要检查的值
@param [integer base] 进制，默认为十进制
@return number
]]
function checknumber(value, base)
    return tonumber(value, base) or 0
end

--[[--
检查并尝试转换为整数，如果无法转换则返回 0
@param mixed value 要检查的值
@return integer
]]
function checkint(value)
    return math.round(checknumber(value))
end

--[[--
检查并尝试转换为布尔值，除了 nil 和 false，其他任何值都会返回 true
@param mixed value 要检查的值
@return boolean
]]
function checkbool(value)
    return (value ~= nil and value ~= false)
end

--[[--
检查值是否是一个表格，如果不是则返回一个空表格
@param mixed value 要检查的值
@return table
]]
function checktable(value)
    if type(value) ~= "table" then value = {} end
    return value
end

--[[--
如果表格中指定 key 的值为 nil，或者输入值不是表格，返回 false，否则返回 true
@param table hashtable 要检查的表格
@param mixed key 要检查的键名
@return boolean
]]
function isset(hashtable, key)
    local t = type(hashtable)
    return (t == "table" or t == "userdata") and hashtable[key] ~= nil
end

--[[--
深度克隆一个值
@param mixed object 要克隆的值
@return mixed
]]
function clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

--[[--
获取调用者的文件名
]]
local function get_caller()
    local info = debug.getinfo(3, "S")  -- 获取第3层堆栈caller
    return info and info.source or ""
end

--[[--
创建一个类
@param string clsname 类名
@param [mixed super] 父类或者创建对象实例的函数
@return table
]]
function class(clsname, super)
    local _name2cls = _G._name2cls
    if not _name2cls then
        _name2cls = {}
        _G._name2cls = _name2cls
    end
    local cls = _name2cls[clsname]
    if cls then
        print("class already defined, will override" .. clsname)
        return cls
    end
    
    local superType = type(super)
    if superType ~= "function" and superType ~= "table" then
        superType = nil
        super = nil
    end

    if superType == "function" or (super and super.__ctype == 1) then
        -- inherited from native C++ Object
        cls = {}
        if superType == "table" then
            -- copy fields from super
            for k,v in pairs(super) do cls[k] = v end
            cls.__create = super.__create
            cls.super    = super
        else
            cls.__create = super
            cls.ctor = function() end
        end
        cls.__cname = clsname
        cls.__ctype = 1
        function cls.new(...)
            local instance = cls.__create(...)
            -- copy fields from class to native object
            for k,v in pairs(cls) do instance[k] = v end
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    else
        -- inherited from Lua Object
        if super then
            cls = {}
            setmetatable(cls, {__index = super})
            cls.super = super
        else
            cls = {ctor = function() end}
        end
        cls.__cname = clsname
        cls.__ctype = 2 -- lua
        cls.__index = cls
        function cls.new(...)
            local instance = setmetatable({}, cls)
            instance.class = cls
            instance:ctor(...)
            return instance
        end
    end
    _name2cls[clsname] = cls

    return cls
end

--[[--
如果对象是指定类或其子类的实例，返回 true，否则返回 false
@param mixed obj 要检查的对象
@param string clsname 类名
@return boolean
]]
function iskindof(obj, clsname)
    local t = type(obj)
    local mt
    if t == "table" then
        mt = getmetatable(obj)
    end

    while mt do
        if mt.__cname == clsname then
            return true
        end
        mt = mt.super
    end

    return false
end

--[[--

载入一个模块

import() 与 require() 功能相同，但具有一定程度的自动化特性。

假设我们有如下的目录结构：

~~~

app/
app/classes/
app/classes/MyClass.lua
app/classes/MyClassBase.lua
app/classes/data/Data1.lua
app/classes/data/Data2.lua

~~~

MyClass 中需要载入 MyClassBase 和 MyClassData。如果用 require()，MyClass 内的代码如下：

~~~ lua

local MyClassBase = require("app.classes.MyClassBase")
local MyClass = class("MyClass", MyClassBase)

local Data1 = require("app.classes.data.Data1")
local Data2 = require("app.classes.data.Data2")

~~~

假如我们将 MyClass 及其相关文件换一个目录存放，那么就必须修改 MyClass 中的 require() 命令，否则将找不到模块文件。

而使用 import()，我们只需要如下写：

~~~ lua

local MyClassBase = import(".MyClassBase")
local MyClass = class("MyClass", MyClassBase)

local Data1 = import(".data.Data1")
local Data2 = import(".data.Data2")

~~~

当在模块名前面有一个"." 时，import() 会从当前模块所在目录中查找其他模块。因此 MyClass 及其相关文件不管存放到什么目录里，我们都不再需要修改 MyClass 中的 import() 命令。这在开发一些重复使用的功能组件时，会非常方便。

我们可以在模块名前添加多个"." ，这样 import() 会从更上层的目录开始查找模块。

~

不过 import() 只有在模块级别调用（也就是没有将 import() 写在任何函数中）时，才能够自动得到当前模块名。如果需要在函数中调用 import()，那么就需要指定当前模块名：

~~~ lua

# MyClass.lua

# 这里的 ... 是隐藏参数，包含了当前模块的名字，所以最好将这行代码写在模块的第一行
local CURRENT_MODULE_NAME = ...

local function testLoad()
    local MyClassBase = import(".MyClassBase", CURRENT_MODULE_NAME)
    # 更多代码
end

~~~
@param string moduleName 要载入的模块的名字
@param [string currentModuleName] 当前模块名
@return module
]]
function import(moduleName, currentModuleName)
    local currentModuleNameParts
    local moduleFullName = moduleName
    local offset = 1

    while true do
        if string.byte(moduleName, offset) ~= 46 then -- .
            moduleFullName = string.sub(moduleName, offset)
            if currentModuleNameParts and #currentModuleNameParts > 0 then
                moduleFullName = table.concat(currentModuleNameParts, ".") .. "." .. moduleFullName
            end
            break
        end
        offset = offset + 1

        if not currentModuleNameParts then
            if not currentModuleName then
                local n,v = debug.getlocal(3, 1)
                currentModuleName = v
            end

            currentModuleNameParts = string.split(currentModuleName, ".")
        end
        table.remove(currentModuleNameParts, #currentModuleNameParts)
    end

    return require(moduleFullName)
end

--[[--
将 Lua 对象及其方法包装为一个匿名函数
@param mixed obj Lua 对象
@param function method 对象方法
@return function
]]
function handler(obj, method)
    assert("function" == type(method), "handler error: the method is not a function!")
    return function(...)
        return method(obj, ...)
    end
end

-- 与 handler 类似
function timerHandler(method, obj, data)
    return function(...)
        if obj and data then
            return method(obj, data, ...)
        elseif obj and not data then
            return method(obj, ...)
        else
            return method(...)
        end
    end
end


--------------------------------
-- @module io

--[[--
检查指定的文件或目录是否存在，如果存在返回 true，否则返回 false
]]
function io.exists(path)
    local file = io.open(path, "r")
    if file then
        io.close(file)
        return true
    end
    return false
end

--[[--
读取文件内容，返回包含文件内容的字符串，如果失败返回 nil
io.readfile() 会一次性读取整个文件的内容，并返回一个字符串，因此该函数不适宜读取太大的文件。
]]
function io.readfile(path)
    local file = io.open(path, "r")
    if file then
        local content = file:read("*a")
        io.close(file)
        return content
    end
    return nil
end

--[[--
以字符串内容写入文件，成功返回 true，失败返回 false
"mode 写入模式" 参数决定 io.writefile() 如何写入内容，可用的值如下：
-   "w+" : 覆盖文件已有内容，如果文件不存在则创建新文件
-   "a+" : 追加内容到文件尾部，如果文件不存在则创建文件
此外，还可以在 "写入模式" 参数最后追加字符 "b" ，表示以二进制方式写入数据，这样可以避免内容写入不完整。
**Android 特别提示:** 在 Android 平台上，文件只能写入存储卡所在路径，assets 和 data 等目录都是无法写入的。
]]
function io.writefile(path, content, mode)
    mode = mode or "w+b"
    local file = io.open(path, mode)
    if file then
        if file:write(content) == nil then return false end
        io.close(file)
        return true
    else
        return false
    end
end

--[[--
拆分一个路径字符串，返回组成路径的各个部分
~~~ lua
local pathinfo  = io.pathinfo("/var/app/test/abc.png")
-- 结果:
-- pathinfo.dirname  = "/var/app/test/"
-- pathinfo.filename = "abc.png"
-- pathinfo.basename = "abc"
-- pathinfo.extname  = ".png"
]]
function io.pathinfo(path)
    local pos = string.len(path)
    local extpos = pos + 1
    while pos > 0 do
        local b = string.byte(path, pos)
        if b == 46 then -- 46 = char "."
            extpos = pos
        elseif b == 47 then -- 47 = char "/"
            break
        end
        pos = pos - 1
    end

    local dirname = string.sub(path, 1, pos)
    local filename = string.sub(path, pos + 1)
    extpos = extpos - pos
    local basename = string.sub(filename, 1, extpos - 1)
    local extname = string.sub(filename, extpos)
    return {
        dirname = dirname,
        filename = filename,
        basename = basename,
        extname = extname
    }
end

--------------------------------
-- 返回指定文件的大小，如果失败返回 false
-- @function [parent=#io] filesize
-- @param string path 文件完全路径
-- @return integer#integer 
function io.filesize(path)
    local size = false
    local file = io.open(path, "r")
    if file then
        local current = file:seek()
        size = file:seek("end")
        file:seek("set", current)
        io.close(file)
    end
    return size
end


--------------------------------
-- @module table

--[[--
计算表格包含的字段数量
Lua table 的 "#" 操作只对依次排序的数值下标数组有效，table.nums() 则计算 table 中所有不为 nil 的值的个数。
]]
function table.nums(t)
    local count = 0
    for k, v in pairs(t) do
        count = count + 1
    end
    return count
end
--[[--
返回指定表格中的所有键
local hashtable = {a = 1, b = 2, c = 3}
local keys = table.keys(hashtable)
-- keys = {"a", "b", "c"}
]]
function table.keys(hashtable)
    local keys = {}
    for k, v in pairs(hashtable) do
        keys[#keys + 1] = k
    end
    return keys
end

--[[--
返回指定表格中的所有值
local hashtable = {a = 1, b = 2, c = 3}
local values = table.values(hashtable)
-- values = {1, 2, 3}
]]
function table.values(hashtable)
    local values = {}
    for k, v in pairs(hashtable) do
        values[#values + 1] = v
    end
    return values
end

--[[--
将来源表格中所有键及其值复制到目标表格对象中，如果存在同名键，则覆盖其值
local dest = {a = 1, b = 2}
local src  = {c = 3, d = 4}
table.merge(dest, src)
-- dest = {a = 1, b = 2, c = 3, d = 4}
]]
function table.merge(dest, src)
    for k, v in pairs(src) do
        dest[k] = v
    end
end

function table.append(dest, src)
    if dest and src then
        for _, v in ipairs(src) do
            table.insert(dest, v)
        end
    end
end

--[[--
在目标表格的指定位置插入来源表格，如果没有指定位置则连接两个表格
local dest = {1, 2, 3}
local src  = {4, 5, 6}
table.insertto(dest, src)
-- dest = {1, 2, 3, 4, 5, 6}
dest = {1, 2, 3}
table.insertto(dest, src, 5)
-- dest = {1, 2, 3, nil, 4, 5, 6}
]]
function table.insertto(dest, src, begin)
	begin = checkint(begin)
	if begin <= 0 then
		begin = #dest + 1
	end

	local len = #src
	for i = 0, len - 1 do
		dest[i + begin] = src[i + 1]
	end
end

--[[--
从表格中查找指定值，返回其索引，如果没找到返回 false
local array = {"a", "b", "c"}
print(table.indexof(array, "b")) -- 输出 2
]]
function table.indexof(array, value, begin)
    for i = begin or 1, #array do
        if array[i] == value then return i end
    end
	return false
end

--[[--
从表格中查找指定值，返回其 key，如果没找到返回 nil
local hashtable = {name = "dualface", comp = "chukong"}
print(table.keyof(hashtable, "chukong")) -- 输出 comp
]]
function table.keyof(hashtable, value)
    for k, v in pairs(hashtable) do
        if v == value then return k end
    end
    return nil
end

--[[--
从表格中删除指定值，返回删除的值的个数
local array = {"a", "b", "c", "c"}
print(table.removebyvalue(array, "c", true)) -- 输出 2
]]
function table.removebyvalue(array, value, removeall)
    local c, i, max = 0, 1, #array
    while i <= max do
        if array[i] == value then
            table.remove(array, i)
            c = c + 1
            i = i - 1
            max = max - 1
            if not removeall then break end
        end
        i = i + 1
    end
    return c
end

--[[--
对表格中每一个值执行一次指定的函数，并用函数返回值更新表格内容
local t = {name = "dualface", comp = "chukong"}
table.map(t, function(v, k)
    -- 在每一个值前后添加括号
    return "[" .. v .. "]"
end)
-- 输出修改后的表格内容
for k, v in pairs(t) do
    print(k, v)
end
-- 输出
-- name [dualface]
-- comp [chukong]
fn 参数指定的函数具有两个参数，并且返回一个值。原型如下：
function map_function(value, key)
    return value
end
]]
function table.map(t, fn)
    for k, v in pairs(t) do
        t[k] = fn(v, k)
    end
end

--[[--
对表格中每一个值执行一次指定的函数，但不改变表格内容
]]
function table.walk(t, fn)
    for k,v in pairs(t) do
        fn(v, k)
    end
end

--[[--
对表格中每一个值执行一次指定的函数，如果该函数返回 false，则对应的值会从表格中删除
local t = {name = "dualface", comp = "chukong"}
table.filter(t, function(v, k)
    return v ~= "dualface" -- 当值等于 dualface 时过滤掉该值
end)
-- 输出修改后的表格内容
for k, v in pairs(t) do
    print(k, v)
end
-- 输出
-- comp chukong
fn 参数指定的函数具有两个参数，并且返回一个 boolean 值。原型如下：
function map_function(value, key)
    return true or false
end
]]
function table.filter(t, fn)
    for k, v in pairs(t) do
        if not fn(v, k) then t[k] = nil end
    end
end

--[[--
遍历表格，确保其中的值唯一
local t = {"a", "a", "b", "c"} -- 重复的 a 会被过滤掉
local n = table.unique(t)
for k, v in pairs(n) do
    print(v)
end
-- 输出
-- a
-- b
-- c
]]
function table.unique(t, bArray)
    local check = {}
    local n = {}
    local idx = 1
    for k, v in pairs(t) do
        if not check[v] then
            if bArray then
                n[idx] = v
                idx = idx + 1
            else
                n[k] = v
            end
            check[v] = true
        end
    end
    return n
end

-- 判断是否为空表
function table.empty(t)
    return not next(t)
end

-- 查找value在t中的位置
function table.find(t, value)
    for k,v in pairs(t) do
        if v == value then
            return k
        end
    end
end

-- 反转table
function table.reverse(t)
    local ret = {}
    for k,v in pairs(t) do
        ret[v] = k
    end
    return ret
end

-- 判断2个table数据是否完全一致(注意：tab不能自循环, 不要有元表)
function table.equal(tab1, tab2)
    if type(tab1) ~= "table" or type(tab2) ~= "table" then
        return false
    end
    if table.nums(tab1) ~= table.nums(tab2) then
        return false
    end
    for k,v in pairs(tab1) do
        if type(v) == "table" then
            if type(tab2[k]) == "table" then
                if table.nums(v) ~= table.nums(tab2[k]) then
                    return false
                end
                local equ = table.equal(v, tab2[k])
                if not equ then
                    return false
                end
            else
                return false
            end
        elseif v ~= tab2[k] then
            return false
        end
    end
    return true
end

--------------------------------
-- @module string


string._htmlspecialchars_set = {}
string._htmlspecialchars_set["&"] = "&amp;"
string._htmlspecialchars_set["\""] = "&quot;"
string._htmlspecialchars_set["'"] = "&#039;"
string._htmlspecialchars_set["<"] = "&lt;"
string._htmlspecialchars_set[">"] = "&gt;"

--[[--
将特殊字符转为 HTML 转义符
print(string.htmlspecialchars("<ABC>"))
-- 输出 &lt;ABC&gt;
]]
function string.htmlspecialchars(input)
    for k, v in pairs(string._htmlspecialchars_set) do
        input = string.gsub(input, k, v)
    end
    return input
end

--[[--
将 HTML 转义符还原为特殊字符，功能与 string.htmlspecialchars() 正好相反
print(string.restorehtmlspecialchars("&lt;ABC&gt;"))
]]
function string.restorehtmlspecialchars(input)
    for k, v in pairs(string._htmlspecialchars_set) do
        input = string.gsub(input, v, k)
    end
    return input
end

--[[--
将字符串中的 \n 换行符转换为 HTML 标记
print(string.nl2br("Hello\nWorld"))
-- 输出
-- Hello<br />World
]]
function string.nl2br(input)
    return string.gsub(input, "\n", "<br />")
end

--[[--
将字符串中的特殊字符和 \n 换行符转换为 HTML 转移符和标记
print(string.text2html("<Hello>\nWorld"))
-- 输出
-- &lt;Hello&gt;<br />World
]]
function string.text2html(input)
    input = string.gsub(input, "\t", "    ")
    input = string.htmlspecialchars(input)
    input = string.gsub(input, " ", "&nbsp;")
    input = string.nl2br(input)
    return input
end

--[[--
用指定字符或字符串分割输入字符串，返回包含分割结果的数组
local input = "Hello,World"
local res = string.split(input, ",")
-- res = {"Hello", "World"}

local input = "Hello-+-World-+-Quick"
local res = string.split(input, "-+-")
-- res = {"Hello", "World", "Quick"}
]]
function string.split(input, delimiter)
    input = tostring(input)
    delimiter = tostring(delimiter)
    if (delimiter=='') then return false end
    local pos,arr = 0, {}
    -- for each divider found
    for st,sp in function() return string.find(input, delimiter, pos, true) end do
        table.insert(arr, string.sub(input, pos, st - 1))
        pos = sp + 1
    end
    table.insert(arr, string.sub(input, pos))
    return arr
end

--[[--
去除输入字符串头部的空白字符，返回结果
local input = "  ABC"
print(string.ltrim(input))
-- 输出 ABC，输入字符串前面的两个空格被去掉了
空白字符包括：
-   空格
-   制表符 \t
-   换行符 \n
-   回到行首符 \r
]]
function string.ltrim(input)
    return string.gsub(input, "^[ \t\n\r]+", "")
end

--[[--
去除输入字符串尾部的空白字符，返回结果
local input = "ABC  "
print(string.rtrim(input))
-- 输出 ABC，输入字符串最后的两个空格被去掉了
]]
function string.rtrim(input)
    return string.gsub(input, "[ \t\n\r]+$", "")
end

--[[--
去掉字符串首尾的空白字符，返回结果
]]
function string.trim(input)
    input = string.gsub(input, "^[ \t\n\r]+", "")
    return string.gsub(input, "[ \t\n\r]+$", "")
end

--[[--
将字符串的第一个字符转为大写，返回结果
local input = "hello"
print(string.ucfirst(input))
-- 输出 Hello
]]
function string.ucfirst(input)
    return string.upper(string.sub(input, 1, 1)) .. string.sub(input, 2)
end

local function urlencodechar(char)
    return "%" .. string.format("%02X", string.byte(char))
end

--[[--
将字符串转换为符合 URL 传递要求的格式，并返回转换结果
local input = "hello world"
print(string.urlencode(input))
-- 输出
-- hello%20world
]]
function string.urlencode(input)
    -- convert line endings
    input = string.gsub(tostring(input), "\n", "\r\n")
    -- escape all characters but alphanumeric, '.' and '-'
    input = string.gsub(input, "([^%w%.%- ])", urlencodechar)
    -- convert spaces to "+" symbols
    return string.gsub(input, " ", "+")
end

--[[--
将 URL 中的特殊字符还原，并返回结果
local input = "hello%20world"
print(string.urldecode(input))
-- 输出
-- hello world
]]
function string.urldecode(input)
    input = string.gsub (input, "+", " ")
    input = string.gsub (input, "%%(%x%x)", function(h) return string.char(checknumber(h,16)) end)
    input = string.gsub (input, "\r\n", "\n")
    return input
end

--[[--
计算 UTF8 字符串的长度，每一个中文算一个字符
local input = "你好World"
print(string.utf8len(input))
-- 输出 7
]]
function string.utf8len(input)
    local len  = string.len(input)
    local left = len
    local cnt  = 0
    local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while left ~= 0 do
        local tmp = string.byte(input, -left)
        local i   = #arr
        while arr[i] do
            if tmp >= arr[i] then
                left = left - i
                break
            end
            i = i - 1
        end
        cnt = cnt + 1
    end
    return cnt
end

--首字母大写
string.capitalize = function(s)
    return string.upper(s[1]) .. string.sub(s, 2)
end


math.Inf = 1 / 0

math.NanOrInf = function(num)
    return num ~= num or num == math.INF
end
