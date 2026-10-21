#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-${SCRIPT_DIR}/../config/cluster.env}"
[[ "$(hostname -s)" == "team-16-nn" ]] || {
  echo "Run this script on team-16-nn" >&2
  exit 1
}
[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }

python3 - "$ENV_FILE" <<'PY'
import os
import secrets
import sys
import tempfile
from pathlib import Path

path = Path(sys.argv[1])
content = path.read_text()
example = 'METASTORE_DB_PASSWORD="CHANGE_ME_BEFORE_SETUP"'
if content.count(example) != 1:
    raise SystemExit("Expected the example password exactly once; inspect cluster.env manually.")

content = content.replace(example, f'METASTORE_DB_PASSWORD="{secrets.token_hex(16)}"')
fd, temporary_name = tempfile.mkstemp(dir=path.parent, prefix=".cluster.env.")
try:
    with os.fdopen(fd, "w") as temporary:
        temporary.write(content)
    os.chmod(temporary_name, 0o600)
    os.replace(temporary_name, path)
finally:
    if os.path.exists(temporary_name):
        os.unlink(temporary_name)
print("Generated a private metastore password in config/cluster.env (not displayed).")
PY
