#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config/cluster.env"

archive="spark-${SPARK_VERSION}-bin-hadoop3.tgz"
install_dir="/opt/spark-${SPARK_VERSION}-bin-hadoop3"
download_dir="/tmp/spark-download"
download_url="https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}"

if [[ -e "$SPARK_HOME" || -L "$SPARK_HOME" ]]; then
  [[ "$(readlink -f "$SPARK_HOME")" == "$install_dir" ]] || {
    echo "$SPARK_HOME points to another Spark installation" >&2
    exit 1
  }
  [[ -x "$SPARK_HOME/bin/spark-submit" ]] || { echo "Spark installation is incomplete" >&2; exit 1; }
  echo "Spark is already installed at $SPARK_HOME"
  exit 0
fi

mkdir -p "$download_dir"
if [[ ! -f "$download_dir/$archive" ]]; then
  curl -fL --retry 3 -o "$download_dir/$archive.part" "$download_url/$archive"
  mv "$download_dir/$archive.part" "$download_dir/$archive"
fi
curl -fL --retry 3 -o "$download_dir/$archive.sha512" "$download_url/$archive.sha512"

(cd "$download_dir" && sha512sum -c "$archive.sha512")

if [[ ! -d "$install_dir" ]]; then
  sudo tar -xzf "$download_dir/$archive" -C /opt
fi
[[ -x "$install_dir/bin/spark-submit" ]] || { echo "Spark installation is incomplete" >&2; exit 1; }
sudo ln -s "$install_dir" "$SPARK_HOME"

echo "Spark ${SPARK_VERSION} installed at $SPARK_HOME"
