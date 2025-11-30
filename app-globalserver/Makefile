##########################################################################################
# Platform auto detect
##########################################################################################
SUPPORTED_PLATFORMS := linux darwin
PLATFORMNAME        ?= $(shell echo $(shell uname) | tr "[:upper:]" "[:lower:]")
$(if $(findstring $(PLATFORMNAME),$(SUPPORTED_PLATFORMS)),,$(error "Unsupported os, must be one of '$(SUPPORTED_PLATFORMS)'"))

##########################################################################################
# Compile commands
##########################################################################################
.PHONY: all darwin macosx clean help

all: $(PLATFORMNAME)

linux:
	@echo "========== make skynet start =========="
	$(shell find ./skynet/3rd/jemalloc -type f -name "*.sh" -exec chmod +x {} \;)
	cd ./skynet;make clean;make linux SKYNET_DEFINES=""
	@echo "========== make skynet end =========="

	@echo "========== make lua-json start =========="
	cd ./game/lib/lua-json;make linux
	@echo "========== make lua-json end =========="

	@echo "========== make lua-encrypt start =========="
	cd ./game/lib/lua-encrypt;make linux
	@echo "========== make lua-encrypt end =========="

	@echo "========== make lua-crc32 start =========="
	cd ./game/lib/lua-crc32;make linux
	@echo "========== make lua-crc32 end =========="

	@echo "========== make lua-lfs start =========="
	cd ./game/lib/lua-lfs;make linux
	@echo "========== make lua-lfs end =========="

	@echo "========== make lua-curl start =========="
	cd ./game/lib/lua-curl;make linux
	@echo "========== make lua-curl end =========="

	@echo "========== make lua-zset start =========="
	cd ./game/lib/lua-zset;make linux
	@echo "========== make lua-zset end =========="

	@echo "========== make lua-extra start =========="
	cd ./game/lib/lua-extra;make linux
	@echo "========== make lua-extra end =========="

	@echo "========== make lua-hmac_sha256 start =========="
	cd ./game/lib/lua-hmac_sha256;make linux
	@echo "========== make lua-hmac_sha256 end =========="

	@echo "========== make lua-snowflake start =========="
	cd ./game/lib/lua-snowflake;make linux
	@echo "========== make lua-snowflake end =========="

	@echo "========== make lua-conhash start =========="
	cd ./game/lib/lua-conhash;make linux
	@echo "========== make lua-conhash end =========="

	@echo "========== make lua-timer start =========="
	cd ./game/lib/lua-timer;make linux
	@echo "========== make lua-timer end =========="

	@echo "========== make lua-socket start =========="
	cd ./game/lib/lua-socket;make linux
	@echo "========== make lua-socket end =========="

	@echo "========== make lua-chash start =========="
	cd ./game/lib/lua-chash;make linux
	@echo "========== make lua-chash end =========="

	@echo "========== rm *.o start =========="
	find ./ -name *.o | xargs rm -f
	@echo "========== rm *.o end =========="

macosx: darwin

darwin:
	@echo "========== make skynet start =========="
	cd ./skynet;make macosx MALLOC_STATICLIB= SKYNET_DEFINES="-DNOUSE_JEMALLOC"
	@echo "========== make skynet end =========="

	@echo "========== make lua-json start =========="
	cd ./game/lib/lua-json;make macosx
	@echo "========== make lua-json end =========="

	@echo "========== make lua-encrypt start =========="
	cd ./game/lib/lua-encrypt;make macosx
	@echo "========== make lua-encrypt end =========="

	@echo "========== make lua-crc32 start =========="
	cd ./game/lib/lua-crc32;make macosx
	@echo "========== make lua-crc32 end =========="

	@echo "========== make lua-lfs start =========="
	cd ./game/lib/lua-lfs;make macosx
	@echo "========== make lua-lfs end =========="

	@echo "========== make lua-curl start =========="
	cd ./game/lib/lua-curl;make macosx
	@echo "========== make lua-curl end =========="

	@echo "========== make lua-zset start =========="
	cd ./game/lib/lua-zset;make macosx
	@echo "========== make lua-zset end =========="

	@echo "========== make lua-extra start =========="
	cd ./game/lib/lua-extra;make macosx
	@echo "========== make lua-extra end =========="

	@echo "========== make lua-hmac_sha256 start =========="
	cd ./game/lib/lua-hmac_sha256;make macosx
	@echo "========== make lua-hmac_sha256 end =========="

	@echo "========== make lua-snowflake start =========="
	cd ./game/lib/lua-snowflake;make macosx
	@echo "========== make lua-snowflake end =========="

	@echo "========== make lua-conhash start =========="
	cd ./game/lib/lua-conhash;make macosx
	@echo "========== make lua-conhash end =========="

	@echo "========== make lua-timer start =========="
	cd ./game/lib/lua-timer;make macosx
	@echo "========== make lua-timer end =========="

	@echo "========== make lua-socket start =========="
	cd ./game/lib/lua-socket;make macosx
	@echo "========== make lua-socket end =========="

	@echo "========== make lua-chash start =========="
	cd ./game/lib/lua-chash;make macosx
	@echo "========== make lua-chash end =========="

	@echo "========== rm *.o start =========="
	find ./ -name *.o | xargs rm -f
	@echo "========== rm *.o end =========="
	
clean:
	@echo "========== clean skynet start =========="
	cd ./skynet;make cleanall
	@echo "========== clean skynet end =========="

	@echo "========== clean lua-json start =========="
	cd ./game/lib/lua-json;make clean
	@echo "========== clean lua-json end =========="

	@echo "========== clean lua-encrypt start =========="
	cd ./game/lib/lua-encrypt;make clean
	@echo "========== clean lua-encrypt end =========="

	@echo "========== clean lua-crc32 start =========="
	cd ./game/lib/lua-crc32;make clean
	@echo "========== clean lua-crc32 end =========="

	@echo "========== clean lua-lfs start =========="
	cd ./game/lib/lua-lfs;make clean
	@echo "========== clean lua-lfs end =========="

	@echo "========== clean lua-curl start =========="
	cd ./game/lib/lua-curl;make clean
	@echo "========== clean lua-curl end =========="

	@echo "========== clean lua-zset start =========="
	cd ./game/lib/lua-zset;make clean
	@echo "========== clean lua-zset end =========="

	@echo "========== clean lua-extra start =========="
	cd ./game/lib/lua-extra;make clean
	@echo "========== clean lua-extra end =========="

	@echo "========== clean lua-hmac_sha256 start =========="
	cd ./game/lib/lua-hmac_sha256;make clean
	@echo "========== clean lua-hmac_sha256 end =========="

	@echo "========== clean lua-snowflake start =========="
	cd ./game/lib/lua-snowflake;make clean
	@echo "========== clean lua-snowflake end =========="

	@echo "========== clean lua-conhash start =========="
	cd ./game/lib/lua-conhash;make clean
	@echo "========== clean lua-conhash end =========="

	@echo "========== clean lua-timer start =========="
	cd ./game/lib/lua-timer;make clean
	@echo "========== clean lua-timer end =========="

	@echo "========== clean lua-socket start =========="
	cd ./game/lib/lua-socket;make clean
	@echo "========== clean lua-socket end =========="

	@echo "========== clean lua-chash start =========="
	cd ./game/lib/lua-chash;make clean
	@echo "========== clean lua-chash end =========="

help:
	@echo "  * linux"
	@echo "  * macosx"
	@echo "  * clean"
