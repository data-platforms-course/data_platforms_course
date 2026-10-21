#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${1:-${BASE_DIR}/config/cluster.env}"
[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
source "$ENV_FILE"

: "${HADOOP_HOME:?Set HADOOP_HOME in cluster.env}"
: "${HIVE_HOME:?Set HIVE_HOME in cluster.env}"
: "${HIVE_SERVER2_HOST:?Set HIVE_SERVER2_HOST in cluster.env}"
: "${HIVE_SERVER2_PORT:?Set HIVE_SERVER2_PORT in cluster.env}"
: "${HIVE_CLIENT_USER:?Set HIVE_CLIENT_USER in cluster.env}"
: "${HDFS_USER:?Set HDFS_USER in cluster.env}"
: "${HIVE_TABLE_LOCATION:?Set HIVE_TABLE_LOCATION in cluster.env}"
[[ "$HIVE_TABLE_LOCATION" =~ ^/[A-Za-z0-9_./=-]+$ ]] || {
  echo "HIVE_TABLE_LOCATION must be a simple absolute HDFS path" >&2
  exit 1
}

export HADOOP_HOME HIVE_HOME
export HADOOP_CONF_DIR="${HADOOP_CONF_DIR:-${HADOOP_HOME}/etc/hadoop}"
[[ -f "${HADOOP_CONF_DIR}/core-site.xml" ]] || {
  echo "Hadoop configuration not found under ${HADOOP_CONF_DIR}" >&2
  exit 1
}
[[ "$HDFS_USER" =~ ^[A-Za-z0-9_]+$ ]] || {
  echo "HDFS_USER must contain only letters, digits or underscores" >&2
  exit 1
}

hdfs="${HADOOP_HOME}/bin/hdfs"
beeline="${HIVE_HOME}/bin/beeline"
jdbc_url="jdbc:hive2://${HIVE_SERVER2_HOST}:${HIVE_SERVER2_PORT}/default"
temporary_file="$(mktemp)"
trap 'rm -f "$temporary_file"' EXIT

for date in 2026-10-01 2026-10-02; do
  partition_dir="${HIVE_TABLE_LOCATION}/event_date=${date}"
  "$hdfs" dfs -mkdir -p "$partition_dir"

  if [[ "$date" == "2026-10-01" ]]; then
    printf '1,100\n2,200\n' > "$temporary_file"
  else
    printf '3,300\n' > "$temporary_file"
  fi

  "$hdfs" dfs -put -f "$temporary_file" "${partition_dir}/events.csv"
done

"$beeline" -u "$jdbc_url" -n "$HIVE_CLIENT_USER" \
  --hivevar "table_location=${HIVE_TABLE_LOCATION}" \
  -f "${BASE_DIR}/sql/setup_table.sql"

echo "Data loaded into course_hw3.events"
