#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-${SCRIPT_DIR}/../config/cluster.env}"
[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
source "$ENV_FILE"

: "${HIVE_HOME:?Set HIVE_HOME in cluster.env}"
: "${METASTORE_DB_NAME:?Set METASTORE_DB_NAME in cluster.env}"
: "${METASTORE_DB_USER:?Set METASTORE_DB_USER in cluster.env}"
: "${METASTORE_DB_PASSWORD:?Set METASTORE_DB_PASSWORD in cluster.env}"
[[ "$METASTORE_DB_NAME" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid METASTORE_DB_NAME" >&2; exit 1; }
[[ "$METASTORE_DB_USER" =~ ^[A-Za-z0-9_]+$ ]] || { echo "Invalid METASTORE_DB_USER" >&2; exit 1; }
[[ "$METASTORE_DB_PASSWORD" =~ ^[A-Za-z0-9_-]{12,}$ ]] || { echo "Set a private METASTORE_DB_PASSWORD in cluster.env" >&2; exit 1; }
[[ "$METASTORE_DB_PASSWORD" != "CHANGE_ME_BEFORE_SETUP" ]] || { echo "Replace the example password in cluster.env first" >&2; exit 1; }

[[ "$(hostname -s)" == "team-16-nn" ]] || {
  echo "Run this script on team-16-nn; current host is $(hostname -s)" >&2
  exit 1
}
[[ -f "${HIVE_HOME}/conf/hive-site.xml" ]] || {
  echo "Run scripts/2_configure_hive.sh first" >&2
  exit 1
}

sudo apt-get update
sudo apt-get install -y postgresql libpostgresql-jdbc-java

sudo -u postgres psql -v ON_ERROR_STOP=1 <<SQL
DO \$do\$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${METASTORE_DB_USER}') THEN
    ALTER ROLE ${METASTORE_DB_USER} WITH LOGIN PASSWORD '${METASTORE_DB_PASSWORD}';
  ELSE
    CREATE ROLE ${METASTORE_DB_USER} LOGIN PASSWORD '${METASTORE_DB_PASSWORD}';
  END IF;
END
\$do\$;
SQL

if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${METASTORE_DB_NAME}'" | grep -q 1; then
  sudo -u postgres createdb --owner="${METASTORE_DB_USER}" "${METASTORE_DB_NAME}"
fi

JDBC_JAR="$(find /usr/share/java -maxdepth 1 -type f -name 'postgresql*.jar' ! -name '*jdbc3*' ! -name '*jdbc4*' | sort | head -n 1)"
[[ -n "$JDBC_JAR" ]] || { echo "PostgreSQL JDBC jar not found under /usr/share/java" >&2; exit 1; }
sudo install -o "$(id -un)" -g "$(id -gn)" -m 644 "$JDBC_JAR" "${HIVE_HOME}/lib/postgresql-jdbc.jar"

export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
export HADOOP_CONF_DIR="${HADOOP_HOME}/etc/hadoop"
if "${HIVE_HOME}/bin/schematool" -dbType postgres -info >/dev/null 2>&1; then
  echo "Metastore schema already exists; leaving it unchanged."
else
  "${HIVE_HOME}/bin/schematool" -dbType postgres -initSchema --verbose
fi

"${HIVE_HOME}/bin/schematool" -dbType postgres -validate
echo "PostgreSQL metastore is ready on $(hostname -s)."
