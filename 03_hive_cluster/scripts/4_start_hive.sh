#!/usr/bin/env bash
set -euo pipefail

ROLE="${1:-}"
[[ "$ROLE" == "metastore" || "$ROLE" == "hiveserver2" ]] || {
  echo "Usage: $0 metastore|hiveserver2" >&2
  exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${2:-${SCRIPT_DIR}/../config/cluster.env}"
[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
source "$ENV_FILE"

: "${HIVE_HOME:?Set HIVE_HOME in cluster.env}"
: "${HADOOP_HOME:?Set HADOOP_HOME in cluster.env}"
[[ -x "${HIVE_HOME}/bin/hive" ]] || { echo "Hive is not installed at ${HIVE_HOME}" >&2; exit 1; }
[[ -f "${HIVE_HOME}/conf/hive-site.xml" ]] || { echo "Run scripts/2_configure_hive.sh first" >&2; exit 1; }

short_host="$(hostname -s)"
if [[ "$ROLE" == "metastore" && "$short_host" != "team-16-nn" ]]; then
  echo "Start the metastore on team-16-nn (current host: ${short_host})" >&2
  exit 1
fi
if [[ "$ROLE" == "hiveserver2" && "$short_host" != "team-16-en" ]]; then
  echo "Start HiveServer2 on team-16-en (current host: ${short_host})" >&2
  exit 1
fi

if sudo systemctl cat "hive-${ROLE}.service" >/dev/null 2>&1; then
  echo "hive-${ROLE}.service already exists; inspect it before changing it." >&2
  exit 1
fi

JAVA_BIN="$(readlink -f "$(command -v java)")"
JAVA_HOME="$(dirname "$(dirname "$JAVA_BIN")")"
PID_DIR_SETTING=""
if [[ "$ROLE" == "hiveserver2" ]]; then
  PID_DIR_SETTING="Environment=HIVESERVER2_PID_DIR=/tmp"
fi
tmp_unit="$(mktemp)"
trap 'rm -f "$tmp_unit"' EXIT
cat >"$tmp_unit" <<UNIT
[Unit]
Description=Apache Hive ${ROLE}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=team
Group=team
WorkingDirectory=/home/team
Environment=JAVA_HOME=${JAVA_HOME}
Environment=HADOOP_HOME=${HADOOP_HOME}
Environment=HADOOP_CONF_DIR=${HADOOP_HOME}/etc/hadoop
Environment=HIVE_HOME=${HIVE_HOME}
Environment=HIVE_CONF_DIR=${HIVE_HOME}/conf
${PID_DIR_SETTING}
Environment=HADOOP_HEAPSIZE=512
ExecStart=${HIVE_HOME}/bin/hive --service ${ROLE}
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT

sudo install -o root -g root -m 644 "$tmp_unit" "/etc/systemd/system/hive-${ROLE}.service"
sudo systemctl daemon-reload
sudo systemctl enable --now "hive-${ROLE}.service"
sudo systemctl --no-pager --full status "hive-${ROLE}.service"

if [[ "$ROLE" == "metastore" ]]; then
  port="${METASTORE_PORT:-9083}"
else
  port="${HIVE_SERVER2_PORT:-10000}"
fi

for attempt in {1..60}; do
  if ss -lnt | grep -Eq ":${port}[[:space:]]"; then
    echo "Hive ${ROLE} is listening on port ${port}"
    exit 0
  fi
  sleep 2
done

echo "Hive ${ROLE} did not open port ${port}" >&2
exit 1
