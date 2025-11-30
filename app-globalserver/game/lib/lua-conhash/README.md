一致性hash

libconhash
=========

一致性哈希
----------

一致哈希 是一种特殊的哈希算法。在使用一致哈希算法后，哈希表槽位数（大小）的改变平均只需要对K/n 个关键字重新映射，其中 K是关键字的数量，n是槽位数量。然而在传统的哈希表中，添加或删除一个槽位的几乎需要对所有关键字进行重新映射。
需求:在使用n台缓存服务器时，一种常用的负载均衡方式是，对资源o的请求使用hash(o) = o mod n来映射到某一台缓存服务器。当增加或减少一台缓存服务器时这种方式可能会改变所有资源对应的hash值，也就是所有的缓存都失效了，这会使得缓存服务器大量集中地向原始内容服务器更新缓存。因些需要一致哈希算法来避免这样的问题。 一致哈希尽可能使同一个资源映射到同一台缓存服务器。这种方式要求增加一台缓存服务器时，新的服务器尽量分担存储其他所有服务器的缓存资源。减少一台缓存服务器时，其他所有服务器也可以尽量分担存储它的缓存资源。 一致哈希算法的主要思想是将每个缓存服务器与一个或多个哈希值域区间关联起来，其中区间边界通过计算缓存服务器对应的哈希值来决定。（定义区间的哈希函数不一定和计算缓存服务器哈希值的函数相同，但是两个函数的返回值的范围需要匹配。）如果一个缓存服务器被移除，则它会从对应的区间会被并入到邻近的区间，其他的缓存服务器不需要任何改变。
实现:一致哈希将每个对象映射到圆环边上的一个点，系统再将可用的节点机器映射到圆环的不同位置。查找某个对象对应的机器时，需要用一致哈希算法计算得到对象对应圆环边上位置，沿着圆环边上查找直到遇到某个节点机器，这台机器即为对象应该保存的位置。 当删除一台节点机器时，这台机器上保存的所有对象都要移动到下一台机器。添加一台机器到圆环边上某个点时，这个点的下一台机器需要将这个节点前对应的对象移动到新机器上。 更改对象在节点机器上的分布可以通过调整节点机器的位置来实现。


libconhash库
------------

libconhash是一个一致性哈希库,具有如下一些特性:

- 1. 易用性, libconhash使用红黑树算法来管理所有的节点。
- 2. 支持多种哈希算法，默认使用MD5算法, 支持用户自定义的哈希函数.
- 3. 根据节点的能力很容易进行随时扩展.

编译libconhash(linux)
----------------
```
 make clean
 make all
```

编译debug版本：
```
 make CFLAG=DEBUG
```

使用libconhash
---------------

包含头文件：libconhash.h and configure.h
然后链接静态库libconhash即可.






---------lua 测试例子
local chashclass = require("chash")
dump("class ==",chashclass,10)
chash = chashclass.new()
chash:addnode("192.168.100.1;10091", 50);
chash:addnode("192.168.100.2;10091", 50);
chash:addnode("192.168.100.3;10091", 50);
chash:addnode("192.168.100.4;10091", 50);

print("virtual nodes number == ",chash:count())
for i=1,30 do
    local rediskey = "Redis-key.km0" .. i
    if i < 10 then
        rediskey = "Redis-key.km00" .. i
    end
    -- [Redis-key.km001] is in node: [192.168.100.1;10091]
    local nodestr = chash:lookup( rediskey )
    print("[",rediskey,"] is in node: [", nodestr,"]")
    if i == 15 then
        chash:delete("192.168.100.4;10091")
    elseif i == 20 then
        chash:addnode("192.168.100.4;10091",50)
    end
end
local rediskey = "Redis-key.km015"
local nodestr = chash:lookup( rediskey )
print("[",rediskey,"] is in node: [", nodestr,"]")
skynet.sleep(100)





















#include <stdio.h>
#include <stdlib.h>
#include "conhash.h"

struct node_s g_nodes[64];
int main()
{
    int i;
    const struct node_s *node;
    char str[128];
    long hashes[512];

    /* init conhash instance */
    struct conhash_s *conhash = conhash_init(NULL);
    if(conhash)
    {
        /* set nodes */
        conhash_set_node(&g_nodes[0], "titanic", 32);
        conhash_set_node(&g_nodes[1], "terminator2018", 24);
        conhash_set_node(&g_nodes[2], "Xenomorph", 25);
        conhash_set_node(&g_nodes[3], "True Lies", 10);
        conhash_set_node(&g_nodes[4], "avantar", 48);

        /* add nodes */
        conhash_add_node(conhash, &g_nodes[0]);
        conhash_add_node(conhash, &g_nodes[1]);
        conhash_add_node(conhash, &g_nodes[2]);
        conhash_add_node(conhash, &g_nodes[3]);
        conhash_add_node(conhash, &g_nodes[4]);

        printf("virtual nodes number %d\n", conhash_get_vnodes_num(conhash));
        printf("the hashing results--------------------------------------:\n");

        /* try object */
        for(i = 0; i < 20; i++)
        {
            sprintf(str, "James.km%03d", i);
            node = conhash_lookup(conhash, str);
            if(node) printf("[%16s] is in node: [%16s]\n", str, node->iden);
        }
        conhash_get_vnodes(conhash, hashes, sizeof(hashes)/sizeof(hashes[0]));
        conhash_del_node(conhash, &g_nodes[2]);
        printf("remove node[%s], virtual nodes number %d\n", g_nodes[2].iden, conhash_get_vnodes_num(conhash));
        printf("the hashing results--------------------------------------:\n");
        for(i = 0; i < 20; i++)
        {
            sprintf(str, "James.km%03d", i);
            node = conhash_lookup(conhash, str);
            if(node) printf("[%16s] is in node: [%16s]\n", str, node->iden);
        }
    }
    conhash_fini(conhash);
    return 0;
}


