/**
 * skynet相关拓展
 */
#include <stddef.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <pthread.h>
#include <unistd.h>
#include <signal.h>
#include <lua.h>
#include <lauxlib.h>
#include "skynet.h"
#include "skynet_handle.h"
#include "skynet_mq.h"
#include "skynet_server.h"
#include "skynet_malloc.h"
#include "lua-seri.h"

static uint32_t handler = 0;
static char cmd_str[64] = "stopSignal";

static void my_signal_handler(int sig) {
    char msg[128];
    memset(msg, 0, strlen(msg));
    switch (sig) {
        case SIGINT:
        case SIGTERM:
        case SIGTSTP:
        default:
            sprintf(msg, "received shutdown signal(%d), scheduling shutdown...\n", sig);
            break;
    };
    fprintf(stderr, msg);
    //
    char *data = skynet_strdup(cmd_str);
    fprintf(stdout,"my_signal_handler signal=%d datasz=%d data=%s\n", sig, (int)strlen(data), data);
    struct skynet_message smsg;
    smsg.source = 0;
    smsg.session = 0;
    smsg.data = data;
    smsg.sz = strlen(data) | ((size_t)PTYPE_TEXT << MESSAGE_TYPE_SHIFT);
    skynet_context_push(handler, &smsg);
}

//修改信号处理函数
static int modify_singal_handler(lua_State *L) {
    const char* svrName = luaL_checkstring(L, 1);
    if(svrName == NULL) {
        printf("modify_singal_handler error: no svrName \n");
        return 0;
    }
    assert(svrName);
    handler = skynet_handle_findname(svrName);
    if(handler == 0) {
        printf("modify_singal_handler error: no handler \n");
        return 0;
    }
    fprintf(stdout,"modify_singal_handler svrName=%s handler=%d\n", svrName, handler);

    // register kill sign
    struct sigaction sa;
    /* When the SA_SIGINFO flag is set in sa_flags then sa_sigaction is used. Otherwise, sa_handler is used. */
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sa.sa_handler = my_signal_handler;
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTSTP, &sa, NULL);

    return 0;
}

//重置信号处理函数
static int reset_singal_handler(lua_State *L) {
    fprintf(stderr, "reset_singal_handler shutdown ...\n");

    struct sigaction sa;
    sa.sa_handler = SIG_DFL; //default signal action
    sa.sa_flags = 0;
    sigemptyset(&sa.sa_mask);
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT, &sa, NULL);
    sigaction(SIGTSTP, &sa, NULL);

    raise(SIGINT); // re-raise the signal

    return 0;
}

//c字符串解码
static int cstr_unpack(lua_State *L) {
    if (lua_isnoneornil(L,1)) {
        return 0;
    }
    void *buffer;
    int len;
    if (lua_type(L,1) == LUA_TSTRING) {
        size_t sz;
        buffer = (void *)lua_tolstring(L,1,&sz);
        len = (int)sz;
    } else {
        buffer = lua_touserdata(L,1);
        len = luaL_checkinteger(L,2);
    }
    if (len == 0) {
        return 0;
    }
    //printf("cstr_unpack buffer=%s\n", (char *) buffer);
    lua_pushlstring(L, (char*)buffer, len);
    return 1;
}

int luaopen_lextra(lua_State *l) {
    luaL_Reg reg[] = {
        {"modify_singal_handler", modify_singal_handler},
        {"reset_singal_handler", reset_singal_handler},
        {"cstr_unpack", cstr_unpack},
        {NULL, NULL}
    };
    luaL_newlib(l, reg);
    return 1;
}
