local zlib = require("zlib")
local zlibLib = {}

local compress, uncompress = nil, nil

--压缩
function zlibLib.encode(str)
	if not compress then
		compress = zlib.deflate()
	end
	return compress(str, "finish")
end
--解压
function zlibLib.decode(str)
	if not uncompress then
		uncompress = zlib.inflate()
	end
	return uncompress(str)
end

return zlibLib