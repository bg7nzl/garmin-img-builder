#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

mkdir -p "$VENDOR" "$DATA/osm" "$LOGS"

fetch() {
  local url="$1" dest="$2"
  echo "==> $url"
  echo "    -> $dest"
  wget -c --progress=dot:giga -O "$dest" "$url"
}

if [[ ! -f "$MKGMAP_JAR" ]]; then
  fetch "$MKGMAP_URL" "$VENDOR/mkgmap-${MKGMAP_VER}.zip"
  unzip -qo "$VENDOR/mkgmap-${MKGMAP_VER}.zip" -d "$VENDOR"
fi
if [[ ! -f "$SPLITTER_JAR" ]]; then
  fetch "$SPLITTER_URL" "$VENDOR/splitter-${SPLITTER_VER}.zip"
  unzip -qo "$VENDOR/splitter-${SPLITTER_VER}.zip" -d "$VENDOR"
fi

fetch "$PBF_URL" "$PBF"
fetch "$SEA_URL" "$SEA_ZIP"
fetch "$BOUNDS_URL" "$BOUNDS_ZIP"

echo "==> 下载完成"
ls -lh "$PBF" "$SEA_ZIP" "$BOUNDS_ZIP" "$MKGMAP_JAR" "$SPLITTER_JAR"
