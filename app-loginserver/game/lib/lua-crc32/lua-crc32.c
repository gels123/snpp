#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "lua.h"
#include "lauxlib.h"
#include "ngx_crc32.h"

int lua_f_short ( lua_State *L )
{
    if ( !lua_isstring ( L, 1 ) ) {
        lua_pushnil ( L );
        return 1;
    }

    size_t vlen = 0;
    const char *value = lua_tolstring ( L, 1, &vlen );

    uint32_t    hash;
    hash = ngx_crc32_short((u_char *)value, vlen);
    //printf("hash short key = %d \n",hash);

    lua_pushinteger ( L, hash);
    return 1;
}

int lua_f_long ( lua_State *L )
{
    if ( !lua_isstring ( L, 1 ) ) {
        lua_pushnil ( L );
        return 1;
    }

    size_t vlen = 0;
    const char *value = lua_tolstring ( L, 1, &vlen );

    unsigned long    hash;
    hash = ngx_crc32_long((u_char *)value, vlen);
    //printf("hash long key = %ld \n",hash);

    lua_pushinteger ( L, hash);
    return 1;
}

static uint32_t crc32;

LUALIB_API int luaopen_crc32 ( lua_State *L )
{
    luaL_checkversion(L);

    luaL_Reg l[] = {
        { "short", lua_f_short },
        { "long", lua_f_long },
        { NULL, NULL },
    };
    luaL_newlib(L,l);
    if (ngx_crc32_table_init() != NGX_OK) {
        printf("crc32 init error\n");
        exit(0);
    }
    ngx_crc32_init(crc32);

    return 1;
}
