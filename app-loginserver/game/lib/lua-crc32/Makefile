LUA_VERSION =       5.4
TARGET =            crc32.so
PREFIX =            /usr/local
CFLAGS =            -O3 -Wall -pedantic -DNDEBUG -g -std=gnu99
CADD_CFLAGS =       -fpic 
# LUA_INCLUDE_DIR =   $(PREFIX)/include
LUA_INCLUDE_DIR =   ../../../skynet/3rd/lua

LNX_LDFLAGS = -shared
MAC_LDFLAGS = -bundle -undefined dynamic_lookup

CC = gcc
LDFLAGS = $(MYLDFLAGS)

BUILD_CFLAGS =      -I$(LUA_INCLUDE_DIR) $(CADD_CFLAGS)
OBJS =              ngx_crc32.o lua-crc32.o

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

