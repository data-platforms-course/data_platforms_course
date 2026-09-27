#!/usr/bin/env bash
# Format a fresh NameNode once, then start HDFS services.
# Run from the edge-node after 03_configure_hdfs.sh.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${1:-${BASE_DIR}/config/cluster.env}"

[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"

if ! ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${NAMENODE_HOST}" \
  "test -d ${HDFS_DATA_ROOT}/namenode/current"; then
  ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${NAMENODE_HOST}" \
    "${HADOOP_HOME}/bin/hdfs namenode -format -nonInteractive"
fi

ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${NAMENODE_HOST}" \
  "${HADOOP_HOME}/bin/hdfs --daemon start namenode && \
   ${HADOOP_HOME}/bin/hdfs --daemon start secondarynamenode"

for host in "${DATANODE_HOSTS[@]}"; do
  if [[ "$host" == "$EDGE_HOST" ]]; then
    "${HADOOP_HOME}/bin/hdfs" --daemon start datanode
  else
    ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${host}" \
      "${HADOOP_HOME}/bin/hdfs --daemon start datanode"
  fi
done
