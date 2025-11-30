local crc32 = require "crc32"
print("crc32 short. ==",crc32.short("hello world"))
print("crc32 long. ==",crc32.long("hello world2"))