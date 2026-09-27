#!/usr/bin/env bash
# Install Java 11 on the edge-node and all HDFS nodes.
# Run this script from the edge-node.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-${SCRIPT_DIR}/../config/cluster.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Configuration file not found: $ENV_FILE" >&2
  echo "Copy config/cluster.env.example to config/cluster.env first." >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$ENV_FILE"

hosts=("$EDGE_HOST" "$NAMENODE_HOST" "${DATANODE_HOSTS[@]}")

install_java() {
  sudo apt-get update
  sudo apt-get install -y openjdk-11-jdk-headless
}

for host in "${hosts[@]}"; do
  echo "===== Installing Java on ${host} ====="
  if [[ "$host" == "$EDGE_HOST" ]]; then
    install_java
  else
    ssh -i "$INTERNAL_SSH_KEY" -o BatchMode=yes "${HDFS_USER}@${host}" \
      'sudo apt-get update && sudo apt-get install -y openjdk-11-jdk-headless'
  fi
done
