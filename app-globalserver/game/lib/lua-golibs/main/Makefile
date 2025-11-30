LUA_VERSION =       5.4
TARGET =            sensitivewords.so
CFLAGS =            -O3 -g -Wall -Wshadow -Winline -Wunreachable-code -pedantic -DNDEBUG -Wunused-function -std=gnu99
LUA_INCLUDE_DIR =   ../../../../skynet/3rd/lua
LUACLIB =           ./

CC = gcc

all:
	@echo "Usage: $(MAKE) <platform>"
	@echo "  * linux"
	@echo "  * clean"

linux:
	# go mod init sensitivewords
	# go mod tidy
	go build -buildmode=c-shared -o $(LUACLIB)/libgolibs.so golibs.go
	chmod +x $(LUACLIB)/libgolibs.so
	gcc -o $(LUACLIB)/$(TARGET) -shared -fPIC -Wl,-rpath=game/lib/lua-golibs/main -I$(LUA_INCLUDE_DIR) -I$(LUACLIB) -L$(LUACLIB)  lua-sensitivewords.c -lgolibs -lpthread -std=gnu99


clean:
	rm -f *.o *.so *.a golibs
