#!/usr/bin/env bash
export PATH=${PATH}:/usr/local/mysql/bin
chmod +x ./start_login_service.sh ./stop_login_service.sh ./skynet/skynet ./skynet/3rd/lua/lua;
if [ ! -d "./log" ]; then
  mkdir ./log;
fi
chmod 777 ./log;
ulimit -n 65535;
#删除启动成功标志文件
if [ -f "./startsuccess_login" ]; then
  rm -f ./startsuccess_login;
fi

#配置jemalloc
export MALLOC_CONF="background_thread:true,dirty_decay_ms:3000,muzzy_decay_ms:3000"

if [ ! -f "./dbconflocal.lua" ]; then
  #后台启动
  if [ -f "./game/loginstartconf_daemon" ]; then
    rm -f ./game/loginstartconf_daemon;
  fi
  cp ./game/loginstartconf ./game/loginstartconf_daemon;
  sed -i 's/-- daemon/daemon/g' ./game/loginstartconf_daemon;
  `pwd`/skynet/skynet game/loginstartconf_daemon
else
  #控制台启动
  if [ -f "./game/loginstartconf_daemon" ]; then
    rm -f ./game/loginstartconf_daemon;
  fi
  `pwd`/skynet/skynet game/loginstartconf
fi
