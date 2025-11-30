local zlib = require("zlib")

local result = "hello test"

print("==========start test==========")
--压缩测试
local compress = zlib.deflate()
local deflated, eof, bytes_in, bytes_out = compress(result,'finish')
print("deflated, eof, bytes_in, bytes_out",deflated, eof, bytes_in, bytes_out)

--解压测试
local uncompress = zlib.inflate()
local inflated, eof, bytes_in, bytes_out= uncompress(deflated)
print("inflated, eof, bytes_in, bytes_out",inflated, eof, bytes_in, bytes_out)
print("==========test success==========")