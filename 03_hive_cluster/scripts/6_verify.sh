#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${1:-${BASE_DIR}/config/cluster.env}"
[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
source "$ENV_FILE"

: "${HIVE_HOME:?Set HIVE_HOME in cluster.env}"
: "${HIVE_SERVER2_HOST:?Set HIVE_SERVER2_HOST in cluster.env}"
: "${HIVE_SERVER2_PORT:?Set HIVE_SERVER2_PORT in cluster.env}"
: "${HIVE_CLIENT_USER:?Set HIVE_CLIENT_USER in cluster.env}"

export HIVE_HOME HADOOP_HOME
export HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-${HADOOP_HOME}/etc/hadoop}"
[[ -f "${HADOOP_CONF_DIR}/core-site.xml" ]] || {
  echo "Hadoop configuration not found under ${HADOOP_CONF_DIR}" >&2
  exit 1
}

"${HIVE_HOME}/bin/beeline" -u "jdbc:hive2://${HIVE_SERVER2_HOST}:${HIVE_SERVER2_PORT}/default" \
  -n "$HIVE_CLIENT_USER" -f "${BASE_DIR}/sql/verify.sql" | tee "${BASE_DIR}/evidence/verification.txt"
