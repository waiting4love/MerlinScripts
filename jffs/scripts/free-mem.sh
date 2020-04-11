#!/bin/sh

gate=80

cur=`free | grep Mem: | awk '{print int($4/1e3)}'`
logger "Current free memory: "$cur"M"

if [[ $cur -lt $gate ]];then
  logger "Start drop caches..."
  sync && echo 3 > /proc/sys/vm/drop_caches
  cur=`free | grep Mem: | awk '{print int($4/1e3)}'`
  logger "Done, Now free memory: "$cur"M"
fi

