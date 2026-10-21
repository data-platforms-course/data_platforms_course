#!/usr/bin/env bash
set -euo pipefail

ROLE="${1:-}"
[[ "$ROLE" == "metastore" || "$ROLE" == "hiveserver2" ]] || {
  echo "Usage: $0 metastore|hiveserver2" >&2
  exit 1
}
sudo systemctl stop "hive-${ROLE}.service"
sudo systemctl --no-pager status "hive-${ROLE}.service" || true
