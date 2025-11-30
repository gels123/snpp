.PHONY: all clean

TOP=$(PWD)
BUILD_DIR=$(TOP)/..
EX_LIB_DIR=$(TOP)/..
LUA_INCLUDE_DIR =   ../../../../../skynet/3rd/lua

CFLAGS = -g3 -O2 -rdynamic -Wall -I$(TOP)/.. -I$(LUA_INCLUDE_DIR)
SHARED = -fPIC --shared
LDFLAGS = -L$(BUILD_DIR) -Wl,-rpath $(BUILD_DIR)

all: $(EX_LIB_DIR)/lutil.so $(EX_LIB_DIR)/lkcp.so

$(EX_LIB_DIR)/lutil.so: lutil.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ 

$(EX_LIB_DIR)/lkcp.so: lkcp.c  ikcp.c
	gcc $(CFLAGS) $(SHARED) $^ -o $@ $(LDFLAGS)

all:
	-rm -rf $(TOP)/*.a $(TOP)/*.o
	@echo 'make finish!!!!!!!!!!!!!!!!!'

clean:
	-rm -rf *.o *.a
