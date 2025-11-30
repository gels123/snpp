local json = require "json"

local usr_xx ={}
usr_xx["1"] = 22
usr_xx["2"] = 33
usr_xx["3"] = 44

local usr = {}
usr["name"]   = "name5566boy"
usr["age"]    = 72
usr["usr_xx"] = usr_xx

local usr_encode = json.encode(usr)
if usr_encode then
	print("==========start test=========")
	print("usr_encode: "..usr_encode) -- {"usr_xx":{"2":33,"3":44,"1":22},"age":72,"name":"name5566boy"}
end

local usr_msg = json.decode(usr_encode)
if usr_msg then
	print("name: "..usr_msg["name"])
	print("age : "..usr_msg["age"])
	local usr_xx = usr_msg["usr_xx"]

	print("usr_xx...")
	for k, v in pairs (usr_xx) do
	  	print (k, v)
	end
	print("==========test success=========")
end