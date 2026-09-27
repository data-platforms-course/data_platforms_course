#!/usr/bin/env bash
# Render and distribute the HDFS configuration. Run from the edge-node.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${1:-${BASE_DIR}/config/cluster.env}"
WORK_DIR="/tmp/hdfs-config"

[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"

mkdir -p "$WORK_DIR"
sed -e "s|__NAMENODE_HOST__|${NAMENODE_HOST}|g" \
    -e "s|__HDFS_DATA_ROOT__|${HDFS_DATA_ROOT}|g" \
  "${BASE_DIR}/config/core-site.xml.template" > "$WORK_DIR/core-site.xml"
sed -e "s|__NAMENODE_HOST__|${NAMENODE_HOST}|g" \
    -e "s|__SECONDARY_NAMENODE_HOST__|${SECONDARY_NAMENODE_HOST}|g" \
    -e "s|__HDFS_DATA_ROOT__|${HDFS_DATA_ROOT}|g" \
  "${BASE_DIR}/config/hdfs-site.xml.template" > "$WORK_DIR/hdfs-site.xml"
printf '%s\n' "${DATANODE_HOSTS[@]}" > "$WORK_DIR/workers"

configure_local() {
  cp "$WORK_DIR/core-site.xml" "$HADOOP_HOME/etc/hadoop/core-site.xml"
  cp "$WORK_DIR/hdfs-site.xml" "$HADOOP_HOME/etc/hadoop/hdfs-site.xml"
  cp "$WORK_DIR/workers" "$HADOOP_HOME/etc/hadoop/workers"
  grep -qxF "export JAVA_HOME=${JAVA_HOME}" "$HADOOP_HOME/etc/hadoop/hadoop-env.sh" || \
    echo "export JAVA_HOME=${JAVA_HOME}" >> "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"
}

configure_local
mkdir -p "$HDFS_DATA_ROOT/tmp" "$HDFS_DATA_ROOT/datanode"

for host in "$NAMENODE_HOST" "${DATANODE_HOSTS[@]}"; do
  [[ "$host" == "$EDGE_HOST" ]] && continue
  scp -i "$INTERNAL_SSH_KEY" "$WORK_DIR/core-site.xml" "$WORK_DIR/hdfs-site.xml" "$WORK_DIR/workers" \
    "${HDFS_USER}@${host}:/tmp/"
  ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${host}" \
    "cp /tmp/core-site.xml ${HADOOP_HOME}/etc/hadoop/core-site.xml && \
     cp /tmp/hdfs-site.xml ${HADOOP_HOME}/etc/hadoop/hdfs-site.xml && \
     cp /tmp/workers ${HADOOP_HOME}/etc/hadoop/workers && \
     { grep -qxF 'export JAVA_HOME=${JAVA_HOME}' ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh || \
       echo 'export JAVA_HOME=${JAVA_HOME}' >> ${HADOOP_HOME}/etc/hadoop/hadoop-env.sh; }"
done

ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${NAMENODE_HOST}" \
  "mkdir -p ${HDFS_DATA_ROOT}/tmp ${HDFS_DATA_ROOT}/namenode ${HDFS_DATA_ROOT}/secondary"
for host in "${DATANODE_HOSTS[@]}"; do
  [[ "$host" == "$EDGE_HOST" ]] && continue
  ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${host}" \
    "mkdir -p ${HDFS_DATA_ROOT}/tmp ${HDFS_DATA_ROOT}/datanode"
done
