#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/timeb.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "SnowWorkerM1.h"
#include "IdGenerator.h"
#include "YitIdHelper.h"

static bool flag = false;

static inline bool init() {
    if (!flag) {
        printf("luasnowflake init\n");
        flag = true;
        IdGeneratorOptions options = BuildIdGenOptions(1);
        options.Method = 1;
        options.WorkerId = 1;
        options.SeqBitLength = 6;
        SetIdGenerator(options);
    }
}

static int nextid(lua_State *l) {
    init();
    int64_t id = NextId();
    lua_pushinteger(l, id);
    return 1;
}

LUALIB_API int luaopen_snowflake(lua_State *l)
{
    luaL_Reg reg[] = {
        { "nextid", nextid },
        { NULL, NULL }
    };
    luaL_newlib(l, reg);
    return 1;
}

