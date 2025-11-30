#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "../sds.h"
#include "lua.h"
#include "lauxlib.h"
#include "set.h"

extern dictType setDictType;

static dict * mySetDict = NULL;

static robj *
__get_robj(sds key){
    dictEntry * de = dictFind(mySetDict,key);
    if(de && de->v.val)
        return dictGetVal(de);
    return NULL;
}

static int
__new(lua_State *L) {
    const char* key = lua_tostring(L, 1);
    sds keySds = sdsnew(key);
    robj * set = setTypeCreate(keySds);
    printf("new %p \n", set);
    dictAdd(mySetDict,keySds,set);
    return 0;
}

static inline robj*
__to_set(lua_State *L) {
    robj *set = lua_touserdata(L, 1);
    if(set==NULL) {
        luaL_error(L, "must be set object");
    }
    return set;
}

static int
__release(lua_State *L) {
    printf("collect set:%p\n", mySetDict);
    dictIterator *di = dictGetIterator(mySetDict);
    dictEntry *de;
    while((de = dictNext(di)) != NULL) {
        // printf("release ===\n");
        robj* ele = dictGetVal(de);
        if(ele)
            freeSetObject(ele);
    }
    dictReleaseIterator(di);
    dictRelease(mySetDict);
    mySetDict = NULL;
    printf("finish collect set\n");
    return 0;
}

static int
__sadd(lua_State *L){
    int argc = lua_gettop(L);
    const char* key = lua_tostring(L, 1);
    sds keySds = sdsnew(key);
    robj * set = __get_robj(keySds);
    printf("sadd ==%p, %s\n",set, key);
    short ret = 0;
    if(set)
    {
        short i = 0;
        // 前置参数数量
        short firstOperateNum = 1;
        for(;i<argc-firstOperateNum;i++)
        {
            const char* value = lua_tostring(L, i+1+firstOperateNum);
            sds valueSds = sdsnew(value);
            ret = ret + setTypeAdd(set,valueSds);
            sdsfree(valueSds);
        }
    }    
    sdsfree(keySds);
    lua_pushinteger(L,ret);
    return 1;
}

static int
__srem(lua_State *L){
    int argc = lua_gettop(L);
    const char* key = lua_tostring(L, 1);
    sds keySds = sdsnew(key);
    robj * set = __get_robj(keySds);
    printf("sadd ==%p, %s\n",set, key);
    short ret = 0;
    if(set)
    {
        short i = 0;
        // 前置参数数量
        short firstOperateNum = 1;
        for(;i<argc-firstOperateNum;i++)
        {
            const char* value = lua_tostring(L, i+1+firstOperateNum);
            sds valueSds = sdsnew(value);
            ret = ret + setTypeRemove(set,valueSds);
            sdsfree(valueSds);
        }
    }    
    sdsfree(keySds);
    lua_pushinteger(L,ret);
    return 1;
}

static int
__ismember(lua_State *L){
    const char* key = lua_tostring(L, 1);
    sds keySds = sdsnew(key);
    robj * set = __get_robj(keySds);
    printf("__ismember ==%p, %s\n",set, key);
    short ret = 0;
    if(set)
    {
        const char* value = lua_tostring(L, 2);
        sds valueSds = sdsnew(value);
        ret = setTypeIsMember(set,valueSds);
    }    
    sdsfree(keySds);
    lua_pushboolean(L,ret);
    return 1;
}

static int
__sunionDiffGenericCommand(lua_State *L){
    int argc = lua_gettop(L);
    short operate = lua_tointeger(L,1); //第一个参数为操作类型
    printf("suniondiffgeneric argc == %d,operate=%d \n",argc,operate);
    short i = 0;
    // 前置参数数量
    short firstOperateNum = 1;
    robj **sets = zmalloc(sizeof(robj*)*argc);
    for(;i<argc-firstOperateNum;i++)
    {
        const char* key = lua_tostring(L, i+1+firstOperateNum);
        sds keySds = sdsnew(key);
        robj * set = __get_robj(keySds);
        printf("suniondiffgeneric argc == %d,key=%s,%p \n",i,key,set);
        if (checkType(set,OBJ_SET)) {
            sdsfree(keySds);
            zfree(sets);
            // 存入一个nil值
            printf("suniondiffgeneric is not object set\n");
            lua_pushnil(L);
            return 1;
        }
        sets[i] = set;
        sdsfree(keySds);
    }
    robj * dstset = sunionDiffGenericCommand(sets,argc,NULL,operate);
    setTypeIterator * si = setTypeInitIterator(dstset);
    sds ele;
    // 构造一个新的table
    lua_newtable(L);
    int n = 0;
    while((ele = setTypeNextObject(si)) != NULL) {
        n++;
        lua_pushstring(L,ele);
        lua_rawseti(L, -2, n);
        // printf("ret == %s \n",ele);
        sdsfree(ele);
    }
    setTypeReleaseIterator(si);
    freeSetObject(dstset);
    zfree(sets);
    return 1;
}

static int
__sinterGenericCommand(lua_State *L){
    int argc = lua_gettop(L);
    short operate = 0 ;//lua_tointeger(L,1); //第一个参数为操作类型
    printf("sintergeneric argc == %d,operate=%d \n",argc,operate);
    short i = 0;
    // 前置参数数量
    short firstOperateNum = 0;
    robj **sets = zmalloc(sizeof(robj*)*argc);
    for(;i<argc-firstOperateNum;i++)
    {
        const char* key = lua_tostring(L, i+1+firstOperateNum);
        sds keySds = sdsnew(key);
        robj * set = __get_robj(keySds);
        printf("sintergeneric argc == %d,key=%s,%p \n",i,key,set);
        if (checkType(set,OBJ_SET)) {
            sdsfree(keySds);
            zfree(sets);
            // 存入一个nil值
            printf("sintergeneric is not object set\n");
            lua_pushnil(L);
            return 1;
        }
        sets[i] = set;
        sdsfree(keySds);
    }
    robj * dstset = sinterGenericCommand(sets,argc,NULL);
    setTypeIterator * si = setTypeInitIterator(dstset);
    sds ele;
    // 构造一个新的table
    lua_newtable(L);
    int n = 0;
    while((ele = setTypeNextObject(si)) != NULL) {
        n++;
        lua_pushstring(L,ele);
        lua_rawseti(L, -2, n);
        // printf("ret == %s \n",ele);
        sdsfree(ele);
    }
    setTypeReleaseIterator(si);
    freeSetObject(dstset);
    zfree(sets);
    return 1;
}

static int
__scard(lua_State *L){
    const char* key = lua_tostring(L, 1);
    sds keySds = sdsnew(key);
    robj * set = __get_robj(keySds);
    unsigned long count = 0;
    printf("scard argc ,key=%s,%p \n",key,set);
    if (!checkType(set,OBJ_SET)) {
        printf("card ==== \n");
        count = setTypeSize(set);
    }
    sdsfree(keySds);
    lua_pushinteger(L,count);
    return 1;
}

static int
__srandmember(lua_State *L){
    const char* key = lua_tostring(L, 1);
    sds keySds = sdsnew(key);
    robj * set = __get_robj(keySds);
    printf("spop argc ,key=%s,%p \n",key,set);
    sdsfree(keySds);
    if (!checkType(set,OBJ_SET)) {
        printf("spop ==== \n");
        unsigned long count = setTypeSize(set);
        if (count > 0 )
        {
            sds ele;
            int64_t llele;
            int encoding;
            encoding = setTypeRandomElement(set,&ele,&llele);
            if (encoding == OBJ_ENCODING_INTSET) {
                lua_pushinteger(L,llele);
                return 1;
            } else {
                lua_pushstring(L,ele);
                return 1;
            }
        }
    }
    lua_pushnil(L);
    return 1;
}

static int
__smembers(lua_State *L){
    const char* key = lua_tostring(L, 1);
    sds keySds = sdsnew(key);
    robj * set = __get_robj(keySds);
    printf("smember argc ,key=%s,%p \n",key,set);
    if (checkType(set,OBJ_SET)) {
        sdsfree(keySds);
        // 存入一个nil值
        printf("smembers is not object set\n");
        lua_pushnil(L);
        return 1;
    }
    sdsfree(keySds);
    setTypeIterator * si = setTypeInitIterator(set);
    sds ele;
    // 构造一个新的table
    lua_newtable(L);
    int n = 0;
    while((ele = setTypeNextObject(si)) != NULL) {
        n++;
        lua_pushstring(L,ele);
        lua_rawseti(L, -2, n);
        // printf("ret == %s \n",ele);
        sdsfree(ele);
    }
    setTypeReleaseIterator(si);
    return 1;
}

LUALIB_API int 
luaopen_set_c( lua_State *L )
{
    luaL_checkversion(L);
    luaL_Reg l[] = {
        {"new",__new},
        {"sunionDiffGenericCommand",__sunionDiffGenericCommand},
        {"sinterGenericCommand",__sinterGenericCommand},
        {"scard",__scard},
        {"smembers",__smembers},
        {"sadd",__sadd},
        {"srem",__srem},
        {"srandmember",__srandmember},
        {"ismember",__ismember},
        {"release",__release},
        {NULL, NULL}
    };
    luaL_newlib(L,l);
    // 构造集合字典
    if( NULL == mySetDict)
        mySetDict = dictCreate(&setDictType, NULL);

    return 1;
}
