#!/usr/bin/env bash
# Verify that exactly three DataNodes are live and HDFS can replicate a file.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${1:-${BASE_DIR}/config/cluster.env}"

[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
# shellcheck source=/dev/null
source "$ENV_FILE"

sleep 5
report="$("${HADOOP_HOME}/bin/hdfs" dfsadmin -report)"
printf '%s\n' "$report"
grep -q 'Live datanodes (3)' <<< "$report" || { echo "Expected three live DataNodes" >&2; exit 1; }
! grep -qE 'Dead datanodes \([1-9][0-9]*\)' <<< "$report" || { echo "Dead DataNodes detected" >&2; exit 1; }

local_test_file="/tmp/hdfs-cluster-test.txt"
hdfs_test_file="/user/${HDFS_USER}/hdfs-cluster-test.txt"
printf 'HDFS cluster test\n' > "$local_test_file"
"${HADOOP_HOME}/bin/hdfs" dfs -mkdir -p "/user/${HDFS_USER}"
"${HADOOP_HOME}/bin/hdfs" dfs -put -f "$local_test_file" "$hdfs_test_file"
"${HADOOP_HOME}/bin/hdfs" fsck "$hdfs_test_file" -files -blocks -locations
