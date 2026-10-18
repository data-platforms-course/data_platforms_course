#!/bin/bash

cd "$(dirname "$0")"
source ../config/cluster.env
sudo apt update && sudo apt install -y nginx
mkdir -p /tmp/yarn-config

for file in hadoop_web.conf hadoop_proxy.conf; do
    sed -e "s|__NAMENODE_HOST__|$NAMENODE_HOST|g" \
        -e "s|__SECONDARY_NAMENODE_HOST__|$SECONDARY_NAMENODE_HOST|g" \
        -e "s|__DATANODE_0__|${DATANODE_HOSTS[0]}|g" \
        -e "s|__DATANODE_1__|${DATANODE_HOSTS[1]}|g" \
        -e "s|__DATANODE_2__|${DATANODE_HOSTS[2]}|g" \
        -e "s|__DOMAIN__|$DOMAIN|g" \
        ../config/$file.template > /tmp/yarn-config/$file
done

sudo mkdir -p /etc/nginx/snippets
sudo cp /tmp/yarn-config/hadoop_proxy.conf /etc/nginx/snippets/
sudo cp /tmp/yarn-config/hadoop_web.conf /etc/nginx/conf.d/

sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx
