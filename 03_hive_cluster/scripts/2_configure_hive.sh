#!/usr/bin/env bash
set -euo pipefail

ROLE="${1:-}"
[[ "$ROLE" == "metastore" || "$ROLE" == "hiveserver2" ]] || {
  echo "Usage: $0 metastore|hiveserver2 [cluster.env]" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${2:-${SCRIPT_DIR}/../config/cluster.env}"
[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
source "$ENV_FILE"

: "${HIVE_HOME:?Set HIVE_HOME in cluster.env}"
: "${HADOOP_HOME:?Set HADOOP_HOME in cluster.env}"
: "${METASTORE_HOST:?Set METASTORE_HOST in cluster.env}"
: "${METASTORE_PORT:?Set METASTORE_PORT in cluster.env}"
: "${HIVE_SERVER2_PORT:?Set HIVE_SERVER2_PORT in cluster.env}"
: "${HDFS_USER:?Set HDFS_USER in cluster.env}"
: "${HIVE_SERVER2_BIND_HOST:?Set HIVE_SERVER2_BIND_HOST in cluster.env}"

[[ "$METASTORE_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || { echo "Invalid METASTORE_HOST" >&2; exit 1; }
[[ "$METASTORE_PORT" =~ ^[0-9]+$ && "$HIVE_SERVER2_PORT" =~ ^[0-9]+$ ]] || {
  echo "Ports must be numeric" >&2
  exit 1
}
[[ "$HDFS_USER" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid HDFS_USER" >&2; exit 1; }
[[ "$HIVE_SERVER2_BIND_HOST" == "127.0.0.1" ]] || { echo "Keep HiveServer2 bound to 127.0.0.1" >&2; exit 1; }

if [[ "$ROLE" == "metastore" ]]; then
  : "${METASTORE_DB_NAME:?Set METASTORE_DB_NAME in cluster.env}"
  : "${METASTORE_DB_USER:?Set METASTORE_DB_USER in cluster.env}"
  : "${METASTORE_DB_PASSWORD:?Set METASTORE_DB_PASSWORD in cluster.env}"
  [[ "$METASTORE_DB_NAME" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid METASTORE_DB_NAME" >&2; exit 1; }
  [[ "$METASTORE_DB_USER" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid METASTORE_DB_USER" >&2; exit 1; }
  [[ "$METASTORE_DB_PASSWORD" =~ ^[A-Za-z0-9_-]{12,}$ && "$METASTORE_DB_PASSWORD" != "CHANGE_ME_BEFORE_SETUP" ]] || {
    echo "Set a private METASTORE_DB_PASSWORD (12+ letters/digits/_/-), not the example value" >&2
    exit 1
  }
fi

[[ "$(uname -s)" == "Linux" ]] || { echo "Run this script on a Linux VM" >&2; exit 1; }
[[ -x "${HIVE_HOME}/bin/schematool" ]] || { echo "Hive is not installed at ${HIVE_HOME}" >&2; exit 1; }
[[ -d "${HADOOP_HOME}/etc/hadoop" ]] || { echo "Hadoop configuration not found under ${HADOOP_HOME}" >&2; exit 1; }

if [[ "$ROLE" == "metastore" && "$(hostname -s)" != "team-16-nn" ]]; then
  echo "Configure the metastore on team-16-nn (current host: $(hostname -s))" >&2
  exit 1
fi
if [[ "$ROLE" == "hiveserver2" && "$(hostname -s)" != "team-16-en" ]]; then
  echo "Configure HiveServer2 on team-16-en (current host: $(hostname -s))" >&2
  exit 1
fi

CONF_DIR="${HIVE_HOME}/conf"
SITE_FILE="${CONF_DIR}/hive-site.xml"
if [[ -e "$SITE_FILE" ]]; then
  echo "$SITE_FILE already exists. Move it aside after inspecting it, then rerun." >&2
  exit 1
fi

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT
cat >"$tmp_file" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property>
    <name>hive.metastore.uris</name>
    <value>thrift://${METASTORE_HOST}:${METASTORE_PORT}</value>
  </property>
  <property>
    <name>hive.metastore.warehouse.dir</name>
    <value>hdfs:///user/${HDFS_USER}/hive/warehouse</value>
  </property>
  <property>
    <name>hive.metastore.schema.verification</name>
    <value>true</value>
  </property>
  <property>
    <name>metastore.try.direct.sql.ddl</name>
    <value>false</value>
  </property>
  <property>
    <name>hive.execution.engine</name>
    <value>mr</value>
  </property>
  <property>
    <name>hive.server2.thrift.bind.host</name>
    <value>${HIVE_SERVER2_BIND_HOST}</value>
  </property>
  <property>
    <name>hive.server2.thrift.port</name>
    <value>${HIVE_SERVER2_PORT}</value>
  </property>
  <property>
    <name>hive.server2.authentication</name>
    <value>NONE</value>
  </property>
XML

if [[ "$ROLE" == "metastore" ]]; then
  cat >>"$tmp_file" <<XML
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>jdbc:postgresql://localhost:5432/${METASTORE_DB_NAME}</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>org.postgresql.Driver</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>${METASTORE_DB_USER}</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>${METASTORE_DB_PASSWORD}</value>
  </property>
  <property>
    <name>hive.metastore.thrift.bind.host</name>
    <value>${METASTORE_HOST}</value>
  </property>
  <property>
    <name>hive.metastore.port</name>
    <value>${METASTORE_PORT}</value>
  </property>
  <property>
    <name>hive.metastore.event.db.notification.api.auth</name>
    <value>false</value>
  </property>
</configuration>
XML
else
  cat >>"$tmp_file" <<XML
  <property>
    <name>hive.aux.jars.path</name>
    <value>file://${HIVE_HOME}/lib/commons-collections-3.2.2.jar</value>
  </property>
</configuration>
XML
fi

sudo install -o "$(id -un)" -g "$(id -gn)" -m 600 "$tmp_file" "$SITE_FILE"

echo "Hive ${ROLE} configuration written to ${SITE_FILE}"
if [[ "$ROLE" == "metastore" ]]; then
  echo "This file contains the metastore database password; keep it private."
fi
