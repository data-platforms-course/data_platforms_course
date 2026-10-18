#!/bin/bash

cd "$(dirname "$0")"
source ../config/cluster.env

ssh -i $INTERNAL_SSH_KEY $HDFS_USER@$NAMENODE_HOST "$HADOOP_HOME/bin/mapred --daemon stop historyserver"

for host in "${DATANODE_HOSTS[@]}"; do
    if [ "$host" = "$EDGE_HOST" ]; then
        $HADOOP_HOME/bin/yarn --daemon stop nodemanager
    else
        ssh -i $INTERNAL_SSH_KEY $HDFS_USER@$host "$HADOOP_HOME/bin/yarn --daemon stop nodemanager"
    fi
done

ssh -i $INTERNAL_SSH_KEY $HDFS_USER@$NAMENODE_HOST "$HADOOP_HOME/bin/yarn --daemon stop resourcemanager"
