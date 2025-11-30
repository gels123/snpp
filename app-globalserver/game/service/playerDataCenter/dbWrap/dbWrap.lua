local skynet = require("skynet")
local dbconf = require("dbconf")
local dbWrap = class("dbWrap")

-- 构造
function dbWrap:ctor(playerDataCenter, dbtype, confdb, gamedb)
    self.playerDataCenter, self.dbtype, self.confdb, self.gamedb = playerDataCenter, dbtype, confdb, gamedb
end

function dbWrap:get_confdb()
    return self.confdb
end

function dbWrap:get_gamedb()
    return self.gamedb
end

function dbWrap:getAddress()
    assert(false, "dbWrap:getAddress not override")
end

-- override
function dbWrap:query(...)
    assert(false, "dbWrap:query not override")
end

-- override
function dbWrap:update(...)
    assert(false, "dbWrap:update not override")
end

-- override
function dbWrap:delete()
    assert(false, "dbWrap:delete not override")
end

return dbWrap