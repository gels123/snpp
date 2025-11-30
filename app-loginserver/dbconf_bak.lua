-- 服务器配置

local dbconf = {}

-- 游戏配置库配置
dbconf.mysql_confdb =
{
    host = "127.0.0.1", 
    port = 3306,
    database = "game_conf",
    user = "root2",
    password = "1",
    max_packet_size = 1024 * 1024,
    instance = 4,
}

-- 游戏数据库配置
dbconf.mysql_gamedb =
{
    host = "127.0.0.1",
    port = 3306,
    database = "game_data",
    user = "root2",
    password = "1",
    max_packet_size = 1024 * 1024,
    instance = 16,
}

-- 本地redis配置
dbconf.redis =
{
    host="127.0.0.1",
    port=6379,
    db=1,
    auth="1",
    instance = 8,
}

-- 共享redis配置
dbconf.publicRedis =
{
    host="127.0.0.1",
    port=6379,
    db=0,
    auth="1",
    instance = 4,
}

-- 是否开启调试
dbconf.DEBUG = true

-- 是否开启后台
dbconf.BACK_DOOR = true

-- 登陆节点id
dbconf.loginnodeid = 10001

return dbconf