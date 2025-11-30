#include <errno.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <libgen.h>
#include <unistd.h>
#include <string.h>
#include "maxminddb.h"

#include "lua.h"
#include "lauxlib.h"

/*
mac下:
    使用brew安装 $brew install libmaxminddb
linux下:
    执行安装 make install-libmaxminddb
需要copy ip库（GeoIP2-City.mmdb）到server目录下
*/

static short isMMDBOpen = 0;
static MMDB_s mmdb;

int data_ok(MMDB_entry_data_s *entry_data,MMDB_lookup_result_s *result, uint32_t expect_type,const char *description, ...)
{
    va_list keys;
    va_start(keys, description);

    int status = MMDB_vget_value(&result->entry, entry_data, keys);

    va_end(keys);

    return status;
}

int lua_f_open( lua_State *L )
{
    if ( !lua_isstring ( L, 1 ) ) {
        lua_pushnil ( L );
        return 1;
    }
    if(1 == isMMDBOpen)
    {
        lua_pushnil ( L );
        return 1;
    }
    size_t vlen = 0;
    const char *value = lua_tolstring ( L, 1, &vlen );
    char myBuffer[96] = {0};
    memcpy(myBuffer,value,vlen);

    int status = MMDB_open(myBuffer, MMDB_MODE_MMAP, &mmdb);
    if (MMDB_SUCCESS != status) { 
        printf("open mmdb error \n");
        exit(0);
    }
    printf("open mmdb success\n");
    lua_pushinteger(L, (lua_Integer)status);
    isMMDBOpen = 1;
    return 1;
}

int lua_f_close( lua_State *L )
{
    if(1 == isMMDBOpen)
    {
        MMDB_close(&mmdb);
        printf("close mmdb success\n");
    }
    else
    {
        printf("close mmdb failed,file open status=%d\n",isMMDBOpen);
    }
    
    lua_pushinteger(L, (lua_Integer)isMMDBOpen);
    return 1;
}

int lua_f_lookupcountry ( lua_State *L )
{
    if(0 == isMMDBOpen)
    {
      printf("lua_f_lookupcountry failed,file open status=%d\n",isMMDBOpen); 
      exit(0);
    }

    if ( !lua_isstring ( L, 1 ) ) {
        lua_pushnil ( L );
        return 1;
    }

    size_t vlen = 0;
    const char *value = lua_tolstring ( L, 1, &vlen );
    char myBuffer[96] = {0};
    memcpy(myBuffer,value,vlen);

    int gai_error;
    int mmdb_error;
    MMDB_lookup_result_s result = MMDB_lookup_string(&mmdb,myBuffer,&gai_error,&mmdb_error);
    if (0 != gai_error) { 
        printf("MMDB_lookup_string gai_error =%d \n",gai_error);
        lua_pushnil ( L );
        return 1;
    }
    if (MMDB_SUCCESS != mmdb_error) { 
        printf("MMDB_lookup_string mmdb_error =%d \n",mmdb_error);
        lua_pushnil ( L );
        return 1;
    }

    MMDB_entry_data_s entry_data;
    int status = data_ok(&entry_data,&result, MMDB_DATA_TYPE_UTF8_STRING, "country{iso_code}","country", "iso_code", NULL);

    if (entry_data.has_data)
    {
        char retString[64] = {0};
        memcpy(retString,entry_data.utf8_string, entry_data.data_size);
        //printf("find string = %s\n", retString);
        int dlen = strlen(retString) ;
        lua_pushinteger(L, (lua_Integer)status);
        lua_pushlstring ( L, retString, dlen );
        return 2;
    }

    //never exec
    lua_pushinteger(L, (lua_Integer)status);
    lua_pushnil ( L );
    return 2;
}

LUALIB_API int luaopen_maxminddb ( lua_State *L )
{
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "lookupcountry", lua_f_lookupcountry },
        { "open", lua_f_open },
        { "close", lua_f_close },
        { NULL, NULL },
    };
    luaL_newlib(L,l);
    return 1;
}
