#!/usr/bin/env bash
# Download, verify, and install Hadoop on every cluster node.
# Run from the edge-node after 01_install_java.sh.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-${SCRIPT_DIR}/../config/cluster.env}"

[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"

ARCHIVE="/tmp/hadoop-${HADOOP_VERSION}.tar.gz"
BASE_URL="https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}"

if [[ ! -f "$ARCHIVE" ]]; then
  curl --fail --location --output "$ARCHIVE" "$BASE_URL/$(basename "$ARCHIVE")"
  curl --fail --location --output "${ARCHIVE}.sha512" "$BASE_URL/$(basename "$ARCHIVE").sha512"
  expected="$(grep -oE '[[:xdigit:]]{128}' "${ARCHIVE}.sha512" | head -n 1)"
  actual="$(sha512sum "$ARCHIVE" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || { echo "Checksum verification failed" >&2; exit 1; }
fi

install_local() {
  sudo tar -xzf "$ARCHIVE" -C /opt
  sudo chown -R "${HDFS_USER}:${HDFS_USER}" "/opt/hadoop-${HADOOP_VERSION}"
  sudo ln -sfn "/opt/hadoop-${HADOOP_VERSION}" "$HADOOP_HOME"
}

install_local

declare -A seen_hosts=()
for host in "$NAMENODE_HOST" "$SECONDARY_NAMENODE_HOST" "${DATANODE_HOSTS[@]}"; do
  [[ -n "${seen_hosts[$host]:-}" ]] && continue
  seen_hosts["$host"]=1
  [[ "$host" == "$EDGE_HOST" ]] && continue
  scp -i "$INTERNAL_SSH_KEY" "$ARCHIVE" "${HDFS_USER}@${host}:${ARCHIVE}"
  ssh -i "$INTERNAL_SSH_KEY" "${HDFS_USER}@${host}" \
    "sudo tar -xzf ${ARCHIVE} -C /opt && \
     sudo chown -R ${HDFS_USER}:${HDFS_USER} /opt/hadoop-${HADOOP_VERSION} && \
     sudo ln -sfn /opt/hadoop-${HADOOP_VERSION} ${HADOOP_HOME}"
done
