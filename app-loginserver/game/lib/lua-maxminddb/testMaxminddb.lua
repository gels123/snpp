local maxminddb = require("maxminddb")
maxminddb.open("/Users/ltzd/work/git_workspace/kingdom-of-heaven-loginserver/GeoIP2-City.mmdb")
math.randomseed( tonumber(tostring(os.time()):reverse():sub(1,6)) ) --随机数
for i=1,1 do
        --local ip = string.format("%d.%d.%d.%d",math.random(1,254),math.random(1,254),math.random(1,254),math.random(1,254))
        local ip = "2001:0:9d38:6abd:4f7:3431:d0a7:605e"
        local lookupStatus,tmpCountryStr = maxminddb.lookupcountry(ip)
        print("accountAPI.getUidByUser  =",lookupStatus,tmpCountryStr)
end