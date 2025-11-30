LUA_VERSION =       5.3
TARGET =            cjson.so
PREFIX =            /usr/local
CFLAGS =            -O3 -Wall -pedantic -DNDEBUG -std=gnu99
CJSON_CFLAGS =      -fpic 
LUA_INCLUDE_DIR =   $(PREFIX)/include

LNX_LDFLAGS = -shared
MAC_LDFLAGS = -bundle -undefined dynamic_lookup

CC = gcc
LDFLAGS = $(MYLDFLAGS)

FPCONV_OBJS =       fpconv.o

BUILD_CFLAGS =      -I$(LUA_INCLUDE_DIR) $(CJSON_CFLAGS)
OBJS =              lua_cjson.o strbuf.o $(FPCONV_OBJS)

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

