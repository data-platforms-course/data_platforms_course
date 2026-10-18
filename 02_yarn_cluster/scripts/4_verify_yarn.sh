#!/bin/bash

cd "$(dirname "$0")"
source ../config/cluster.env

mkdir -p ../evidence

$HADOOP_HOME/bin/yarn node -list | tee ../evidence/yarn-node-list.txt

> ../evidence/web-ui-check.txt

for port in 8088 19888 9870 9868 18042 18043 18044 19864 19865 19866; do
    code=$(curl -s -o /dev/null -L -w "%{http_code}" http://127.0.0.1:$port/)
    echo "port $port: HTTP $code" | tee -a ../evidence/web-ui-check.txt
done
