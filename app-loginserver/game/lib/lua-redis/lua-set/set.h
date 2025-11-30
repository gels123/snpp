#ifndef MY_SET_H
#define MY_SET_H

#include <limits.h>
#include "../zmalloc.h"
#include "../dict.h"
#include "../sds.h"
#include "../intset.h"


#define LUA_MAXINTEGER      LLONG_MAX
#define LUA_MININTEGER      LLONG_MIN

/* Error codes */
#define C_OK                    0
#define C_ERR                   -1

#define OBJ_SET_MAX_INTSET_ENTRIES 512
#define HASHTABLE_MIN_FILL        10      /* Minimal hash table fill 10% */

/* Sets operations codes */
#define SET_OP_UNION 0
#define SET_OP_DIFF 1
#define SET_OP_INTER 2

#define OBJ_ENCODING_RAW 0     /* Raw representation */
#define OBJ_ENCODING_HT 2      /* Encoded as hash table */
#define OBJ_SET 2       /* Set object. */
#define OBJ_ENCODING_INTSET 6  /* Encoded as intset */
#define LRU_BITS 24
#define LRU_CLOCK_MAX ((1<<LRU_BITS)-1) /* Max value of obj->lru */
#define LRU_CLOCK_RESOLUTION 1000 /* LRU clock resolution in ms */

#define OBJ_SHARED_REFCOUNT INT_MAX

/* Keys hashing / comparison functions for dict.c hash tables. */
uint64_t dictSdsHash(const void *key);
int dictSdsKeyCompare(void *privdata, const void *key1, const void *key2);
void dictSdsDestructor(void *privdata, void *val);
int htNeedsResize(dict *dict);

typedef struct redisObject {
    unsigned type:4;
    unsigned encoding:4;
    unsigned lru:LRU_BITS; /* LRU time (relative to global lru_clock) or
                            * LFU data (least significant 8 bits frequency
                            * and most significant 16 bits access time). */
    int refcount;
    void *ptr;
} robj;

/* Structure to hold set iteration abstraction. */
typedef struct {
    robj *subject;
    int encoding;
    int ii; /* intset iterator */
    dictIterator *di;
} setTypeIterator;

void decrRefCount(robj *o);
void incrRefCount(robj *o);
robj *setTypeCreate(sds value);
void freeSetObject(robj *o);
robj *createIntsetObject(void);
robj *createSetObject(void);
robj *createObject(int type, void *ptr);
void setTypeConvert(robj *subject, int enc);
int setTypeAdd(robj *subject, sds value);
int setTypeRemove(robj *setobj, sds value);
int setTypeIsMember(robj *subject, sds value);
setTypeIterator *setTypeInitIterator(robj *subject);
void setTypeReleaseIterator(setTypeIterator *si);
int setTypeNext(setTypeIterator *si, sds *sdsele, int64_t *llele);
sds setTypeNextObject(setTypeIterator *si);
int setTypeRandomElement(robj *setobj, sds *sdsele, int64_t *llele);
unsigned long setTypeSize(const robj *subject);
void setTypeConvert(robj *setobj, int enc);
int qsortCompareSetsByCardinality(const void *s1, const void *s2);
int qsortCompareSetsByRevCardinality(const void *s1, const void *s2);
int isSdsRepresentableAsLongLong(sds s, long long *llval);
int string2ll(const char *s, size_t slen, long long *value);
// robj *lookupKey(robj *key, int flags);
robj* sunionDiffGenericCommand(robj **sets, int setnum,robj *dstkey, int op);
robj* sinterGenericCommand(robj **sets,unsigned long setnum, robj *dstkey);

#endif
