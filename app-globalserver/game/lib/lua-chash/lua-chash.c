#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"
#include "chash.h"

int lua_f_mul_hash(lua_State *L)
{
    if (!lua_isnumber(L, 1))
    {
        lua_pushnil(L);
        return 1;
    }
    uint32_t v = lua_tonumber(L, 1);
    uint32_t hash = mul_hash(v);
    // printf("lua_f_mul_hash v = %u, hash = %u\n", v, hash);
    lua_pushinteger(L, hash);
    return 1;
}

int lua_f_fnv_hash(lua_State *L)
{
    if (!lua_isstring(L, 1))
    {
        lua_pushnil(L);
        return 1;
    }
    size_t vlen = 0;
    const char *str = lua_tolstring(L, 1, &vlen);
    uint32_t hash = fnv_hash((u_char *)str, vlen);
    // printf("lua_f_fnv_hash str = %s, hash = %u\n", str, hash);
    lua_pushinteger(L, hash);
    return 1;
}

LUALIB_API int luaopen_chash(lua_State *L)
{
    luaL_checkversion(L);

    luaL_Reg l[] = {
        {"mul_hash", lua_f_mul_hash},
        {"fnv_hash", lua_f_fnv_hash},
        {NULL, NULL},
    };
    luaL_newlib(L, l);

    return 1;
}
