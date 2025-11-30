LUA_VERSION =       5.4
TARGET =            snowflake.so
PREFIX =            /usr/local

CFLAGS =            -O3 -Wall -pedantic -DNDEBUG -g -std=gnu99
CADD_CFLAGS =       -fPIC
LUA_INCLUDE_DIR =   ../../../skynet/3rd/lua

LNX_LDFLAGS = -shared
MAC_LDFLAGS = -bundle -undefined dynamic_lookup

CC = gcc
LDFLAGS = $(MYLDFLAGS)

BUILD_CFLAGS =      -I$(LUA_INCLUDE_DIR) -I./ $(CADD_CFLAGS)
OBJS =              luasnowflake.o YitIdHelper.o IdGenerator.o IdGenOptions.o SnowWorkerM1.o SnowWorkerM2.o

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

main:
	$(CC) -o $@ main.c YitIdHelper.c IdGenerator.c IdGenOptions.c SnowWorkerM1.c SnowWorkerM2.c -lpthread

clean:
	rm -f *.o *.a *.so main

