#ifndef _C_HASH_H_
#define _C_HASH_H_

#include <stdio.h>
#include <stdint.h>
#include <string.h>

typedef unsigned int    uint32_t;
typedef unsigned char   u_char;

// const uint32_t MAXUINT32 = 0xffffffff;

/* 
 * 32位 乘法 哈希算法
 */
static inline uint32_t mul_hash(uint32_t v)
{
    return v * 2654435761;
}

/* 
 * 32位 Fowler-Noll-Vo 哈希算法
 * https:en.wikipedia.org/wiki/Fowler–Noll–Vo_hash_function
 */
static inline uint32_t fnv_hash(u_char *str, size_t len)
{
    uint32_t p = 16777619;
    uint32_t hash = 2166136261;
    u_char c;
    while (len--)
    {
        c = *str++;
        // printf("fnv_hash==%c\n", c);
        hash = (hash ^ c) * p;
    }
    hash += hash << 13;
    hash ^= hash >> 7;
    hash += hash << 3;
    hash ^= hash >> 17;
    hash += hash << 5;
    return hash;
}

#endif /* _C_HASH_H_ */
