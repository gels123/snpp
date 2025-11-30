#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "lua.h"
#include "lauxlib.h"

#include "geohash.h"

#define GEO_WGS84_TYPE     1
#define GEO_MERCATOR_TYPE  2

#define D_R (M_PI / 180.0)
#define R_D (180.0 / M_PI)
#define R_MAJOR 6378137.0
#define R_MINOR 6356752.3142
#define RATIO (R_MINOR/R_MAJOR)
#define ECCENT (sqrt(1.0 - (RATIO * RATIO)))
#define COM (0.5 * ECCENT)
/// @brief The usual PI/180 constant
//static const double DEG_TO_RAD = 0.017453292519943295769236907684886;
/// @brief Earth's quatratic mean radius for WGS-84
static const double EARTH_RADIUS_IN_METERS = 6372797.560856;

static const double MERCATOR_MAX = 20037726.37;
//static const double MERCATOR_MIN = -20037726.37;
static const double MAP_MAX = 1200;

static const GeoHashRange LAT_RANGE = {1201,1};
static const GeoHashRange LON_RANGE = {1201,1};

static int lua_f_geohashalign52bits(lua_State *L) 
{
    GeoHashBits hash;
    hash.bits = (uint64_t) lua_tonumber(L, 1);
    hash.step = (uint8_t) lua_tonumber(L, 2);
    uint64_t bits = hash.bits;
    bits <<= (52 - hash.step * 2);
    lua_pushnumber(L,bits);
    return 1;
}

static int lua_f_geohashencode(lua_State *L)
{
    double latitude = lua_tonumber(L, 1);
    double longitude = lua_tonumber(L, 2);

    GeoHashBits hash;

    geohash_encode(LAT_RANGE,LON_RANGE,latitude,longitude,24,&hash);

    uint64_t bits = hash.bits;
    bits <<= (52 - hash.step * 2);

    lua_pushnumber(L,bits);
    return 1;
}

static int lua_f_geofashhashencode(lua_State *L)
{
    double latitude = lua_tonumber(L, 1);
    double longitude = lua_tonumber(L, 2);

    GeoHashBits hash;

    geohash_fast_encode(LAT_RANGE,LON_RANGE,latitude,longitude,24,&hash);

    uint64_t bits = hash.bits;
    bits <<= (52 - hash.step * 2);
    
    lua_pushnumber(L,bits);
    return 1;
}

static int lua_f_hashencode( lua_State *L )
{
    double latitude = lua_tonumber(L, 1);
    double longitude = lua_tonumber(L, 2);

    GeoHashBits hash;

    geohash_encode(LAT_RANGE,LON_RANGE,latitude,longitude,24,&hash);

    lua_pushnumber(L,hash.bits);
    lua_pushnumber(L,hash.step);
    return 2;
}

static int lua_f_hashfastencode( lua_State *L )
{
    double latitude = lua_tonumber(L, 1);
    double longitude = lua_tonumber(L, 2);

    GeoHashBits hash;

    geohash_fast_encode(LAT_RANGE,LON_RANGE,latitude,longitude,24,&hash);

    lua_pushnumber(L,hash.bits);
    lua_pushnumber(L,hash.step);
    return 2;
}

LUALIB_API int 
luaopen_geo_c( lua_State *L )
{
    luaL_checkversion(L);

    luaL_Reg l[] = {
        {"geohash",lua_f_geohashencode},
        {"fastgeohash",lua_f_geofashhashencode},
        {"hashencode",lua_f_hashencode},
        {"hashfastencode",lua_f_hashfastencode},
        {"hashalign52bits",lua_f_geohashalign52bits},
        {NULL, NULL}
    };
    luaL_newlib(L,l);

    return 1;
}
