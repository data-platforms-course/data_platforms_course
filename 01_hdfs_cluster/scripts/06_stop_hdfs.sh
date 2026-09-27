#!/usr/bin/env bash
# Stop HDFS daemons. Run from the edge-node.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${1:-${BASE_DIR}/config/cluster.env}"

[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"

for host in "${DATANODE_HOSTS[@]}"; do
  if [[ "$host" == "$EDGE_HOST" ]]; then
    "${HADOOP_HOME}/bin/hdfs" --daemon stop datanode
  else
    ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${host}" \
      "${HADOOP_HOME}/bin/hdfs --daemon stop datanode"
  fi
done

ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${NAMENODE_HOST}" \
  "${HADOOP_HOME}/bin/hdfs --daemon stop secondarynamenode; \
   ${HADOOP_HOME}/bin/hdfs --daemon stop namenode"
