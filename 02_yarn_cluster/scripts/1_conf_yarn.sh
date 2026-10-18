#!/bin/bash

cd "$(dirname "$0")"
source ../config/cluster.env

mkdir -p /tmp/yarn-config

for file in mapred-site.xml yarn-site.xml; do
    sed "s|__NAMENODE_HOST__|$NAMENODE_HOST|g; s|__HADOOP_HOME__|$HADOOP_HOME|g" \
        ../config/$file.template > /tmp/yarn-config/$file
done

sudo sed -i 's/^127.0.1.1/#127.0.1.1/' /etc/hosts
cp /tmp/yarn-config/*.xml $HADOOP_HOME/etc/hadoop/

for host in $NAMENODE_HOST $SECONDARY_NAMENODE_HOST "${DATANODE_HOSTS[@]}"; do
    if [ "$host" != "$EDGE_HOST" ]; then
        echo "Copying config to $host..."
        ssh -i $INTERNAL_SSH_KEY $HDFS_USER@$host "sudo sed -i 's/^127.0.1.1/#127.0.1.1/' /etc/hosts"
        scp -i $INTERNAL_SSH_KEY /tmp/yarn-config/*.xml $HDFS_USER@$host:$HADOOP_HOME/etc/hadoop/
    fi
done
