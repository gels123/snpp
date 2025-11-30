#include <stddef.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <lua.h>
#include <lauxlib.h>
#include "hmac_sha256.h"

#define SHA256_HASH_SIZE 32
static uint8_t out[SHA256_HASH_SIZE];
static char out_str[SHA256_HASH_SIZE * 2 + 1];

//作为十六进制数据字符串值返回
static int hmac_sha256_hex(lua_State *L) {
    const char* str_key = luaL_checkstring(L, 1);
    const char* str_data = luaL_checkstring(L, 2);

    memset(&out, 0, sizeof(out));
    memset(&out_str, 0, sizeof(out_str));

    hmac_sha256(str_key, strlen(str_key), str_data, strlen(str_data), &out, sizeof(out));

    for (unsigned int i = 0; i < sizeof(out); i++) {
        snprintf(&out_str[i*2], 3, "%02x", out[i]);
    }

    lua_pushlstring(L, out_str, SHA256_HASH_SIZE * 2 + 1);
    return 1;
}

//作为二进制数据字符串值返回
static int hmac_sha256_bit(lua_State *L) {
    const char* str_key = luaL_checkstring(L, 1);
    const char* str_data = luaL_checkstring(L, 2);

    memset(&out, 0, sizeof(out));
    memset(&out_str, 0, sizeof(out_str));

    hmac_sha256(str_key, strlen(str_key), str_data, strlen(str_data), &out, sizeof(out));

    lua_pushlstring(L, (char*)out, SHA256_HASH_SIZE);
    return 1;
}

int luaopen_lhmac_sha256(lua_State *l) {
    luaL_Reg reg[] = {
        {"hmac_sha256_hex", hmac_sha256_hex},
        {"hmac_sha256_bit", hmac_sha256_bit},
        {NULL, NULL}
    };
    luaL_newlib(l, reg);
    return 1;
}
