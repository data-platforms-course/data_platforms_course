#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config/cluster.env"

export HIVE_HOME HADOOP_HOME
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"

"$HADOOP_HOME/bin/hdfs" dfs -test -e "$OUTPUT_PATH" || {
  echo "Spark output not found: $OUTPUT_PATH" >&2
  exit 1
}

"$HIVE_HOME/bin/beeline" -u "$HIVE_URL" -n "$HIVE_USER" \
  --hivevar "output_path=$OUTPUT_PATH" -f "$BASE_DIR/sql/register.sql"
