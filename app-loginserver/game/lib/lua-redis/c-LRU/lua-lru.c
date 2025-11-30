#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "lua.h"
#include "lauxlib.h"

#include "./LRU/lru_cache_impl.h"
#include "./LRU/lru_cache.h"

static inline LRUCacheS*
_to_lru(lua_State *L) {
    LRUCacheS **lru = lua_touserdata(L, 1);
    if(lru==NULL) {
        luaL_error(L, "must be LRUCacheS object");
    }
    return *lru;
}

static int
_new(lua_State *L) {
    if ( !lua_isinteger ( L, 1 ) ) {
        printf("lualru integer error \n");
        return 0;
    }
    void *LruCache;
    lua_Integer capcity = lua_tointeger(L, 1);
    LRUCacheCreate(capcity, &LruCache);
    if (NULL == LruCache)
        printf("create LRUCacheS success,capcity is %d\n",capcity);

    LRUCacheS **lru = (LRUCacheS**) lua_newuserdata(L, sizeof(LRUCacheS*));
    *lru = LruCache;
    lua_pushvalue(L, lua_upvalueindex(1));
    lua_setmetatable(L, -2);
    return 1;
}

static int
_release(lua_State *L) {
    LRUCacheS *lruCache = _to_lru(L);
    // printf("collect lru:%p\n", lru);
    LRUCacheDestory(lruCache);
    return 0;
}

static int 
lua_f_set( lua_State *L )
{
    int argc = lua_gettop(L);    /* number of arguments */
    short ret = 0;
    if(argc != 3)
    {
        printf("lru_c lua_f_set string error =%d \n",argc);
        ret = 2;
    }

    if ( !lua_isstring ( L, 2 ) || !lua_isstring ( L, 3 ) ) {
        ret = 3;
    }

    LRUCacheS *lruCache = _to_lru(L);
    
    if(lruCache != NULL)
    {
        size_t keySize = 0;
        const char *keyBuffer = lua_tolstring ( L, 2, &keySize );
        size_t valueSize = 0;
        const char *valueBuffer = lua_tolstring ( L, 3, &valueSize );        
        if (0 != LRUCacheSet(lruCache, (const char *)keyBuffer, (const char *)valueBuffer))
        {
            ret = 1;
            // printf("put (%s, %s) failed!\n",keyBuffer,valueBuffer);
        }
    }

    lua_pushinteger(L,ret);
    return 1;
}

static int 
lua_f_get( lua_State *L )
{
    int argc = lua_gettop(L);    /* number of arguments */
    short ret = 0;
    if(argc != 2)
    {
        printf("lru_c lua_f_get string error =%d \n",argc);
        ret = 2;
    }

    if ( !lua_isstring ( L, 2 ) ) {
        ret = 3;
    }

    LRUCacheS *lruCache = _to_lru(L);
    char * value = NULL;
    if(lruCache != NULL)
    {
        size_t keySize = 0;
        const char *keyBuffer = lua_tolstring ( L, 2, &keySize );
        
        value = LRUCacheGet(lruCache, keyBuffer);
        if (NULL == value)
        {
            ret = 1;
            // printf("get (%s) failed!\n",keyBuffer);
        }
    }
    short returncount = 1;
    lua_pushinteger(L,ret);
    if( NULL != value )
    {
        lua_pushstring(L, (const char *)value);
        returncount += 1;
    }
    return returncount;
}

static int
lua_f_dump(lua_State *L) {
    LRUCacheS *lruCache = _to_lru(L);
    // printf("collect lru:%p\n", lru);
    LRUCachePrint(lruCache);
    return 0;
}

LUALIB_API int 
luaopen_lru_c( lua_State *L )
{
    luaL_checkversion(L);

    luaL_Reg l[] = {
        {"set",lua_f_set},
        {"get",lua_f_get},
        {"dump",lua_f_dump},
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
