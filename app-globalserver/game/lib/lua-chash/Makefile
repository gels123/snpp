LUA_VERSION =       5.4
TARGET =            chash.so
PREFIX =            /usr/local
CFLAGS =            -O3 -Wall -pedantic -DNDEBUG -g -std=gnu99
CZSET_CFLAGS =      -fpic 
LUA_INCLUDE_DIR =   ../../../skynet/3rd/lua

LNX_LDFLAGS = -shared
MAC_LDFLAGS = -bundle -undefined dynamic_lookup

CC = gcc
LDFLAGS = $(MYLDFLAGS)

BUILD_CFLAGS =      -I$(LUA_INCLUDE_DIR) $(CZSET_CFLAGS)
OBJS =              chash.o lua-chash.o

all:
	@echo "Usage: $(MAKE) <platform>"
	@echo "  * linux"
	@echo "  * macosx"

.c.o:
	$(CC) -c $(LDFLAGS) $(CFLAGS) $(BUILD_CFLAGS) -o $@ $<

linux:
	@$(MAKE) $(TARGET) MYLDFLAGS="$(LNX_LDFLAGS)"

macosx:
	@$(MAKE) $(TARGET) MYLDFLAGS="$(MAC_LDFLAGS)"

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

clean:
	rm -f *.o *.so

