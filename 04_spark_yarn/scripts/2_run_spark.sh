#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config/cluster.env"

[[ -x "$SPARK_HOME/bin/spark-submit" ]] || { echo "Run 1_install_spark.sh first" >&2; exit 1; }
[[ -f "$HADOOP_HOME/etc/hadoop/yarn-site.xml" ]] || { echo "YARN configuration not found" >&2; exit 1; }

export HADOOP_HOME SPARK_HOME
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export YARN_CONF_DIR="$HADOOP_CONF_DIR"
export PYSPARK_PYTHON=python3

"$HADOOP_HOME/bin/hdfs" dfs -test -e "$INPUT_PATH" || {
  echo "HDFS input not found: $INPUT_PATH" >&2
  exit 1
}
"$HADOOP_HOME/bin/hdfs" dfs -ls -R "$INPUT_PATH"

"$SPARK_HOME/bin/spark-submit" \
  --master yarn \
  --deploy-mode client \
  --driver-memory 1g \
  --executor-memory 1g \
  --executor-cores 1 \
  --num-executors 1 \
  --conf spark.sql.shuffle.partitions=2 \
  "$BASE_DIR/src/transform.py" "$INPUT_PATH" "$OUTPUT_PATH"
