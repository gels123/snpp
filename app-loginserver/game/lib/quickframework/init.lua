--[[

Copyright (c) 2011-2014 chukong-inc.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

]]

--------------------------------
-- @module init

--[[--

quick framework 初始化

载入 quick framework 预定义的常量、模块。

<br />

### 自动载入的模块

框架初始化时，会自动载入以下基本模块：

-   debug: 调试接口
-   functions: 提供一组常用的函数，以及对 Lua 标准库的扩展
-   cc: quick 框架扩展的基础类和组件

]]

--print("===========================================================")
--print("              LOAD QUICK FRAMEWORK")
--print("===========================================================")


local CURRENT_MODULE_NAME = ...

cc = cc or {}
cc.PACKAGE_NAME = string.sub(CURRENT_MODULE_NAME, 1, -6)

require(cc.PACKAGE_NAME .. ".debug")
require(cc.PACKAGE_NAME .. ".functions")
require(cc.PACKAGE_NAME .. ".cc.init")



