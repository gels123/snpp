/*
 *  author: xjdrew
 *  date: 2014-06-03 20:38
 */

#include <stdio.h>
#include <stdlib.h>

#include "lua.h"
#include "lauxlib.h"
#include "conhash.h"
#include "conhash_inter.h"


static inline conhash*
_to_conhash(lua_State *L) {
    conhash **_conhash = lua_touserdata(L, 1);
    if(_conhash==0) {
        luaL_error(L, "must be conhash_s object");
    }
    return *_conhash;
}

static int
_addnode(lua_State *L) {
    luaL_checktype(L, 2, LUA_TSTRING);
    luaL_checktype(L, 3, LUA_TNUMBER);
    conhash *_conhash = _to_conhash(L);
    struct node_s *node = malloc(sizeof(struct node_s));

    size_t len;
    const char* iden = lua_tolstring(L, 2, &len);
    int replica = luaL_checkinteger(L, 3);

    conhash_set_node(node, iden, replica);
    conhash_add_node(_conhash, node);
    lua_pushlightuserdata(L, node);
    return 1;
}

static int
_deletnode(lua_State *L) {
    conhash *_conhash = _to_conhash(L);
    luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
    struct node_s *node = lua_touserdata(L,2);
    int success = conhash_del_node(_conhash, node);
    free(node);
    node = 0;
    lua_pushboolean(L, success == 0);
    return 1;
}

static int
_get_count(lua_State *L) {
    conhash *_conhash = _to_conhash(L);
    lua_pushinteger(L, conhash_get_vnodes_num(_conhash));
    return 1;
}

static int
_lookup(lua_State *L) {
    luaL_checktype(L, 2, LUA_TSTRING);
    conhash *_conhash = _to_conhash(L);
    size_t len;
    const char* iden = lua_tolstring(L, 2, &len);

    const struct node_s *node = conhash_lookup(_conhash, iden);
    if(0 == node) {
        return 0;
    }
    lua_pushlightuserdata(L,node);
    return 1;
}

static int
_new(lua_State *L) {
    conhash *phash = conhash_init(NULL);
    conhash **_conhash = (conhash**) lua_newuserdata(L, sizeof(conhash*));
    *_conhash = phash;
    lua_pushvalue(L, lua_upvalueindex(1));
    lua_setmetatable(L, -2);
    return 1;
}

static int
_release(lua_State *L) {
    conhash *_conhash = _to_conhash(L);
    conhash_fini(_conhash);
    _conhash = 0;
    return 0;
}

int luaopen_conhash_c(lua_State *L) {
    luaL_Reg l[] = {
        {"addnode", _addnode},
        {"deletenode", _deletnode},
        {"count", _get_count},
        {"lookup", _lookup},
        {NULL, NULL}
    };

    lua_createtable(L, 0, 2);

    luaL_newlib(L, l);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, _release);
    lua_setfield(L, -2, "__gc");

    lua_pushcclosure(L, _new, 1);
    return 1;
}

