# include ../../skynet.mk

LUA_VERSION =       5.4
TARGET =            encrypt.so
PREFIX =            /usr/local
CFLAGS =            -O3 -Wall -pedantic -DNDEBUG -DUSE_MEM_HOOK
CZSET_CFLAGS =      -fpic 
# LUA_INCLUDE_DIR =   $(PREFIX)/include
LUA_INCLUDE_DIR =   ../../../skynet/3rd/lua

LNX_LDFLAGS = -shared
MAC_LDFLAGS = -bundle -undefined dynamic_lookup

CC = gcc
LDFLAGS = $(MYLDFLAGS)

BUILD_CFLAGS =      -I$(LUA_INCLUDE_DIR) $(CZSET_CFLAGS) -I../../../skynet/skynet-src
OBJS =              lua-encrypt.o

all:
	@echo "Usage: $(MAKE) <platform>"
	@echo "  * linux"
	@echo "  * macosx"

.c.o:
	$(CC) -g -O2 -c $(CFLAGS) $(CPPFLAGS) $(BUILD_CFLAGS) -o $@ $<

linux:
	@$(MAKE) $(TARGET) MYLDFLAGS="$(LNX_LDFLAGS)"

macosx:
	@$(MAKE) $(TARGET) MYLDFLAGS="$(MAC_LDFLAGS)"

$(TARGET): $(OBJS)
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

clean:
	rm -f *.o *.so

