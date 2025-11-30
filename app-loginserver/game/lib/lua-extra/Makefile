TARGET =            lextra.so
CFLAGS =            -O3 -Wall -pedantic -DNDEBUG -std=gnu99 -fpic
LUA_INCLUDE_DIR =   ../../../skynet/3rd/lua
SKYNET_INCLUDE_DIR = ../../../skynet/skynet-src

LNX_LDFLAGS = -shared
MAC_LDFLAGS = -bundle -undefined dynamic_lookup

CC = gcc
LDFLAGS = $(MYLDFLAGS)

BUILD_CFLAGS =      -fPIC -I$(LUA_INCLUDE_DIR) -I$(SKYNET_INCLUDE_DIR) -I../../../skynet/lualib-src
OBJS =              lextra.o

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

