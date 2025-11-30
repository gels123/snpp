/*
 *  author: gels
 *  date: 2023-03-29 15:00
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "lua.h"
#include "lauxlib.h"
#include "libgolibs.h"

int l_sensitiveWordNewFilter(lua_State *L)
{
    GoUintptr filter = sensitiveWordNewFilter();
    GoUintptr* p = (GoUintptr*) lua_newuserdata(L, sizeof(GoUintptr));
    *p = filter;
    printf("l_sensitiveWordNewFilter filter=%lld p=%lld\n", filter, *p);
    lua_pushvalue(L, lua_upvalueindex(1));
    lua_setmetatable(L, -2);
    return 1;
}

int l_sensitiveWordReleaseFilter(lua_State *L)
{
    GoUintptr* p = lua_touserdata(L, 1);
    printf("l_sensitiveWordReleaseFilter p=%lld\n", *p);
    if(p == NULL) {
        luaL_error(L, "l_sensitiveWordReleaseFilter must be sensitiveWordFilter object");
    }
    sensitiveWordDelFilter(*p);
    return 0;
}

int l_sensitiveWordLoadDict(lua_State *L)
{
    GoUintptr* p = lua_touserdata(L, 1);
    GoString path;
    path.n = 0;
    path.p = NULL;
    path.p = luaL_checklstring(L, 2, &path.n);
    printf("l_sensitiveWordLoadDict p=%lld path=%s\n", *p, path.p);
    if(p == NULL || path.p == NULL) {
        luaL_error(L, "l_sensitiveWordLoadDict must be filter object");
    }
    sensitiveWordLoadDict(*p, path);
    return 0;
}

int l_sensitiveWordReplace(lua_State *L)
{
    GoUintptr* p = lua_touserdata(L, 1);
    GoString text;
    text.n = 0;
    text.p = NULL;
    text.p = luaL_checklstring(L, 2, &text.n);
    GoInt32 repl = luaL_checkinteger(L, 3);
//    printf("l_sensitiveWordReplace p=%lld text=%s repl=%d\n", *p, text.p, repl);
    if(p == NULL || text.p == NULL) {
        luaL_error(L, "l_sensitiveWordReplace must be filter object");
    }
    char* ret = sensitiveWordReplace(*p, text, repl);
    lua_pushstring(L, ret);
    freeString(ret);
    return 1;
}

int l_sensitiveWordValidate(lua_State *L)
{
    GoUintptr* p = lua_touserdata(L, 1);
    GoString text;
    text.n = 0;
    text.p = NULL;
    text.p = luaL_checklstring(L, 2, &text.n);
//    printf("l_sensitiveWordValidate p=%lld text=%s\n", *p, text.p);
    if(p == NULL || text.p == NULL) {
        luaL_error(L, "l_sensitiveWordValidate must be filter object");
    }
    GoUint8 ret = sensitiveWordValidate(*p, text);
    lua_pushboolean(L, ret);
    return 1;
}

LUALIB_API int luaopen_sensitivewords(lua_State *L)
{
    luaL_Reg reg[] =
    {
        {"sensitiveWordLoadDict", l_sensitiveWordLoadDict},
        {"sensitiveWordReplace", l_sensitiveWordReplace},
        {"sensitiveWordValidate", l_sensitiveWordValidate},
        {NULL, NULL}
    };
    lua_createtable(L, 0, 2);

    luaL_newlib(L, reg);
    lua_setfield(L, -2, "__index");

    lua_pushcfunction(L, l_sensitiveWordReleaseFilter);
    lua_setfield(L, -2, "__gc");

    lua_pushcclosure(L, l_sensitiveWordNewFilter, 1);
    return 1;
}
