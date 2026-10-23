#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config/cluster.env"

export HIVE_HOME HADOOP_HOME
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"

"$HADOOP_HOME/bin/hdfs" dfs -ls -R "$OUTPUT_PATH"
"$HIVE_HOME/bin/beeline" -u "$HIVE_URL" -n "$HIVE_USER" \
  -f "$BASE_DIR/sql/verify.sql"
