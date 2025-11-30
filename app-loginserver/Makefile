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
	#cd 3rd/jemalloc && ./autogen.sh --with-jemalloc-prefix=je_ --enable-prof --with-malloc-conf=background_thread:true,dirty_decay_ms:3000,muzzy_decay_ms:3000 修改jemalloc参数
	#cd ./skynet;make clean;make linux SKYNET_DEFINES=""
	cd ./skynet;make clean;make linux MALLOC_STATICLIB= SKYNET_DEFINES="-DNOUSE_JEMALLOC"
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

	@echo "========== make lua-redis/geo start =========="
	cd ./game/lib/lua-redis/geo;make linux
	@echo "========== make lua-redis/geo end =========="

	@echo "========== make lua-zlib start =========="
	#cd ./game/lib/lua-zlib;make linux
	@echo "========== make lua-zlib end =========="

	@echo "========== make lua-hmac_sha256 start =========="
	cd ./game/lib/lua-hmac_sha256;make linux
	@echo "========== make lua-hmac_sha256 end =========="

	@echo "========== make lua-snowflake start =========="
	cd ./game/lib/lua-snowflake;make linux
	@echo "========== make lua-snowflake end =========="

	@echo "========== make lua-extra start =========="
	cd ./game/lib/lua-extra;make linux
	@echo "========== make lua-extra end =========="

	@echo "========== make lua-conhash start =========="
	cd ./game/lib/lua-conhash;make linux
	@echo "========== make lua-conhash end =========="

	@echo "========== make lua-maxminddb start =========="
	cd ./game/lib/lua-maxminddb;make linux
	@echo "========== make lua-maxminddb end =========="

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

	@echo "========== make lua-redis/geo start =========="
	cd ./game/lib/lua-redis/geo;make macosx
	@echo "========== make lua-redis/geo end =========="

	@echo "========== make lua-zlib start =========="
	#cd ./game/lib/lua-zlib;make macosx
	@echo "========== make lua-zlib end =========="

	@echo "========== make lua-hmac_sha256 start =========="
	cd ./game/lib/lua-hmac_sha256;make macosx
	@echo "========== make lua-hmac_sha256 end =========="

	@echo "========== make lua-snowflake start =========="
	cd ./game/lib/lua-snowflake;make macosx
	@echo "========== make lua-snowflake end =========="

	@echo "========== make lua-extra start =========="
	cd ./game/lib/lua-extra;make macosx
	@echo "========== make lua-extra end =========="

	@echo "========== make lua-conhash start =========="
	cd ./game/lib/lua-conhash;make macosx
	@echo "========== make lua-conhash end =========="

	@echo "========== make lua-maxminddb start =========="
	#cd ./game/lib/lua-maxminddb;make macosx
	@echo "========== make lua-maxminddb end =========="

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

	@echo "========== clean lua-redis/geo start =========="
	cd ./game/lib/lua-redis/geo;make clean
	@echo "========== clean lua-redis/geo end =========="

	@echo "========== clean lua-zlib start =========="
	cd ./game/lib/lua-zlib;make clean
	@echo "========== clean lua-zlib end =========="

	@echo "========== clean lua-hmac_sha256 start =========="
	cd ./game/lib/lua-hmac_sha256;make clean
	@echo "========== clean lua-hmac_sha256 end =========="

	@echo "========== clean lua-snowflake start =========="
	cd ./game/lib/lua-snowflake;make clean
	@echo "========== clean lua-snowflake end =========="

	@echo "========== clean lua-extra start =========="
	cd ./game/lib/lua-extra;make clean
	@echo "========== clean lua-extra end =========="

	@echo "========== clean lua-conhash start =========="
	cd ./game/lib/lua-conhash;make clean
	@echo "========== clean lua-conhash end =========="

	@echo "========== clean lua-maxminddb start =========="
	#cd ./game/lib/libmaxminddb-1.6.0;make clean
	cd ./game/lib/lua-maxminddb;make clean
	@echo "========== clean lua-maxminddb end =========="

help:
	@echo "  * linux"
	@echo "  * macosx"
	@echo "  * clean"

install-libmaxminddb:
	@echo "========== install-libmaxminddb start =========="
	cd ./game/lib/libmaxminddb-1.6.0;yum -y install automake autoconf libtool;aclocal;autoreconf -ivf;autoheader;automake --add-missing;./configure;make;make check;sudo make install;sudo ldconfig;make clean;find / -name maxminddb.h;
	@echo "========== install-libmaxminddb end =========="

install-uuid:
	@echo "========== install-uuid start =========="
	yum install -y e2fsprogs-devel;yum install -y uuid-devel;yum install -y libuuid-devel;
	@echo "========== install-uuid end =========="
