TARGET =            lru.so
PREFIX =            /usr/local
CFLAGS =            -O0 -g -ggdb -Wall -pedantic # -DNOT_USE_SEMI #(打开可以关闭多线程环境)
CZSET_CFLAGS =      -fPIC
LUA_INCLUDE_DIR =   ../../../../skynet/3rd/lua

LNX_LDFLAGS = -shared -lpthread
MAC_LDFLAGS = -bundle -undefined dynamic_lookup -lpthread

CC = gcc
LDFLAGS = $(MYLDFLAGS)

BUILD_CFLAGS =      -I$(LUA_INCLUDE_DIR) $(CZSET_CFLAGS)
OBJS =              ./LRU/lru_cache_impl.o lua-lru.o

all:
	@echo "Usage: $(MAKE) <platform>"
	@echo "  * linux"
	@echo "  * macosx"

.c.o:
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $(BUILD_CFLAGS) -o $@ $<

linux:
	@$(MAKE) $(TARGET) MYLDFLAGS="$(LNX_LDFLAGS)"

macosx:
	@$(MAKE) $(TARGET) MYLDFLAGS="$(MAC_LDFLAGS)"

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

clean:
	rm -f *.o *.so

