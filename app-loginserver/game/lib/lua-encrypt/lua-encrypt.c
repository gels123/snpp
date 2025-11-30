
#include <stdio.h>
#include <stdlib.h>
#include "lua.h"
#include "lauxlib.h"
#include <string.h>
#include "skynet_malloc.h"

const static int maxPackageSize = 8192000;

int xorCryptSwapIndex[] = {
    1, 11,
    2, 22,
    3, 33,
    4, 44,
    5, 55,
    6, 66,
    7, 77,
    8, 111,
    12, 121,
    13, 131,
    14, 141,
};
static int nXOrSwapNum = 0;

static void printBuffer(const char *pBuffer, int size)
{
	if (NULL == pBuffer || size > maxPackageSize)
	{
		return;
	}

	int i = 0;
	for (; i < size; ++i)
	{
		printf("%c,", pBuffer[i]);
	}
	printf("\n");
}

static void swapBuffer(char* const pBuffer, int size)
{
    if (NULL == pBuffer || size > maxPackageSize || size <=0 || nXOrSwapNum <= 0)
    {
        return;
    }

    int i = 0;
    for (; i < nXOrSwapNum - 1; i += 2) {
        int nFront = xorCryptSwapIndex[i] % size;
        int nBack = xorCryptSwapIndex[i + 1] % size;
        unsigned char tmpChar = pBuffer[nFront];
        pBuffer[nFront] = pBuffer[nBack];
        pBuffer[nBack] = tmpChar;
    }
}


static void swapReverseBuffer(char* const pBuffer, int size)
{
    if (NULL == pBuffer || size > maxPackageSize || size <=0 || nXOrSwapNum <= 0)
    {
        return;
    }
    
    int i = nXOrSwapNum - 1;
    for (; i > 0; i -= 2) {
        int nFront = xorCryptSwapIndex[i] % size;
        int nBack = xorCryptSwapIndex[i - 1] % size;
        unsigned char tmpChar = pBuffer[nFront];
        pBuffer[nFront] = pBuffer[nBack];
        pBuffer[nBack] = tmpChar;
    }
}

static void crypt(char* const pBuffer, int size,const char *key,int nKeyIdxEnd)
{
	if (NULL == pBuffer || size > maxPackageSize || size <= 0 || nKeyIdxEnd < 0 || NULL == key)
	{
		return;
	}

	int i = 0,j = 0;
	for (; i < size; ++i)
	{
		pBuffer[i] ^= key[j];
		if (j < nKeyIdxEnd)
		{
			++j;
		}
		else
		{
			j = 0;
		}
	}
}

static int decrypt(lua_State *L)
{
	char * ptr = (char*)lua_touserdata(L, 1);
	int size = luaL_checkinteger(L, 2);

	size_t keySize = 0;
	const char *keyBuffer = lua_tolstring ( L, 3, &keySize );
	// printf("decrypt =%s ,size=%d\n",keyBuffer,keySize);
	if( size <=2 || NULL == ptr || NULL == keyBuffer || keySize <= 1 )
	{
		char errinfo[64] = {0};
		sprintf(errinfo,"decrypt error,%d,%ld",size,keySize);
		luaL_error(L, errinfo);
		return 0;
	}

	// swapReverseBuffer(ptr, size);
	crypt(ptr, size,keyBuffer,keySize-1);

	return 0;
}

static size_t count_size(lua_State *L, int index) {
	size_t tlen = 0;
	int i;
	for (i=1;lua_geti(L, index, i) != LUA_TNIL; ++i) {
		size_t len;
		luaL_checklstring(L, -1, &len);
		tlen += len;
		lua_pop(L,1);
	}
	lua_pop(L,1);
	return tlen;
}

static void concat_table(lua_State *L, int index, void *buffer, size_t tlen) {
	char *ptr = buffer;
	int i;
	for (i=1;lua_geti(L, index, i) != LUA_TNIL; ++i) {
		size_t len;
		const char * str = lua_tolstring(L, -1, &len);
		if (str == NULL || tlen < len) {
			break;
		}
		memcpy(ptr, str, len);
		ptr += len;
		tlen -= len;
		lua_pop(L,1);
	}
	if (tlen != 0) {
		skynet_free(buffer);
		luaL_error(L, "Invalid strings table");
	}
	lua_pop(L,1);
}

static void* get_buffer(lua_State *L, int index, int *sz) {
	void *buffer;
	switch(lua_type(L, index)) {
		size_t len;
	case LUA_TUSERDATA:
	case LUA_TLIGHTUSERDATA:
		buffer = lua_touserdata(L,index);
		*sz = luaL_checkinteger(L,index+1);
		break;
	case LUA_TTABLE:
		// concat the table as a string
		len = count_size(L, index);
		buffer = skynet_malloc(len);
		concat_table(L, index, buffer, len);
		*sz = (int)len;
		break;
	default:
		buffer = (void*)luaL_checklstring(L, index, &len);
		*sz = (int)len;
		break;
	}
	return buffer;
}

static int encrypt(lua_State *L)
{
	int sz = 0;
	char *buffer = (char*)get_buffer(L, 1, &sz);
	size_t keySize = 0;
	const char *keyBuffer = lua_tolstring ( L, 2, &keySize );
	// printf("encrypt =%s ,size=%d\n",keyBuffer,keySize);
	if( sz <=2 || NULL == buffer || NULL == keyBuffer || keySize <= 1 )
	{
		char errinfo[64] = {0};
		sprintf(errinfo,"decrypt error,%d,%ld",sz,keySize);
		luaL_error(L, errinfo);
		return 0;
	}	

	crypt(buffer + 2, sz - 2,keyBuffer,keySize-1);
	// swapBuffer(buffer + 2, sz - 2);

	return 0;
}

static int encryptc(lua_State *L)
{
	char *buffer =  (char*) lua_touserdata(L,1);
	int sz = luaL_checkinteger(L,2);
	size_t keySize = 0;
	const char *keyBuffer = lua_tolstring ( L, 3, &keySize );
	// printf("encrypt =%s ,size=%d,sz=%d\n",keyBuffer,keySize,sz);
	if( sz <=2 || NULL == buffer || NULL == keyBuffer || keySize <= 1 )
	{
		char errinfo[64] = {0};
		sprintf(errinfo,"decrypt error,%d,%ld",sz,keySize);
		luaL_error(L, errinfo);
		return 0;
	}	

	crypt(buffer + 2, sz - 2,keyBuffer,keySize-1);
	// swapBuffer(buffer + 2, sz - 2);

	return 0;
}

static void initXOrCrypt()
{
    nXOrSwapNum = sizeof(xorCryptSwapIndex) / sizeof(int);
    if (0 != nXOrSwapNum % 2) {
        nXOrSwapNum = 0;
    }
}

int luaopen_encrypt(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "encrypt", encrypt },
		{ "decrypt", decrypt },
		{ "encryptc", encryptc },
		{ NULL, NULL },
	};
	luaL_newlib(L,l);

    initXOrCrypt();

	return 1;
}
