#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-${SCRIPT_DIR}/../config/cluster.env}"
[[ -f "$ENV_FILE" ]] || { echo "Configuration file not found: $ENV_FILE" >&2; exit 1; }
source "$ENV_FILE"

[[ "$(uname -s)" == "Linux" ]] || { echo "Run this script on a Linux VM" >&2; exit 1; }
: "${HIVE_VERSION:?Set HIVE_VERSION in cluster.env}"
: "${HIVE_HOME:?Set HIVE_HOME in cluster.env}"

archive="apache-hive-${HIVE_VERSION}-bin.tar.gz"
download_dir="/tmp/hive-download"
download_url="https://archive.apache.org/dist/hive/hive-${HIVE_VERSION}"
install_dir="/opt/apache-hive-${HIVE_VERSION}-bin"

mkdir -p "$download_dir"
if [[ ! -f "${download_dir}/${archive}" ]]; then
  curl --fail --location --retry 3 --output "${download_dir}/${archive}.partial" \
    "${download_url}/${archive}"
  mv "${download_dir}/${archive}.partial" "${download_dir}/${archive}"
fi
curl --fail --location --retry 3 --output "${download_dir}/${archive}.sha256" \
  "${download_url}/${archive}.sha256"

if ! (
  cd "$download_dir"
  sha256sum --check "${archive}.sha256"
); then
  echo "Archive checksum failed; download it again before installation" >&2
  exit 1
fi

if [[ ! -d "$install_dir" ]]; then
  sudo tar -xzf "${download_dir}/${archive}" -C /opt
fi
[[ -f "${install_dir}/bin/beeline" ]] || {
  echo "Hive installation is incomplete: $install_dir" >&2
  exit 1
}

if [[ -e "$HIVE_HOME" || -L "$HIVE_HOME" ]]; then
  [[ "$(readlink -f "$HIVE_HOME")" == "$install_dir" ]] || {
    echo "$HIVE_HOME already points to another installation" >&2
    exit 1
  }
else
  sudo ln -s "$install_dir" "$HIVE_HOME"
fi

echo "Hive ${HIVE_VERSION} installed at ${HIVE_HOME}"
