#!/bin/bash

cd "$(dirname "$0")"
source ../config/cluster.env

$HADOOP_HOME/bin/hdfs dfs -mkdir -p /tmp/logs /user/$HDFS_USER
$HADOOP_HOME/bin/hdfs dfs -chmod 1777 /tmp /tmp/logs

ssh -i $INTERNAL_SSH_KEY $HDFS_USER@$NAMENODE_HOST "$HADOOP_HOME/bin/yarn --daemon start resourcemanager"

for host in "${DATANODE_HOSTS[@]}"; do
    if [ "$host" = "$EDGE_HOST" ]; then
        $HADOOP_HOME/bin/yarn --daemon start nodemanager
    else
        ssh -i $INTERNAL_SSH_KEY $HDFS_USER@$host "$HADOOP_HOME/bin/yarn --daemon start nodemanager"
    fi
done

ssh -i $INTERNAL_SSH_KEY $HDFS_USER@$NAMENODE_HOST "$HADOOP_HOME/bin/mapred --daemon start historyserver"

sleep 15
$HADOOP_HOME/bin/yarn node -list
