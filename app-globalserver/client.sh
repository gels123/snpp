#!/usr/bin/env bash
export PATH=${PATH}:/usr/local/mysql/bin
rlwrap ./skynet/3rd/lua/lua ./game/service/simulate/simAgent.lua $1 $2 $3

