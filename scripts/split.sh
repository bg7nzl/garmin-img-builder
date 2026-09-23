#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

if [[ ! -f "$PBF" ]]; then
  echo "缺少 $PBF，先跑 scripts/fetch.sh" >&2
  exit 1
fi
if [[ ! -f "$SPLITTER_JAR" ]]; then
  echo "缺少 $SPLITTER_JAR，先跑 scripts/fetch.sh" >&2
  exit 1
fi

rm -rf "$TILES"
mkdir -p "$TILES" "$LOGS"

SPLIT_SEA=()
if [[ -f "$SEA_ZIP" ]]; then
  SPLIT_SEA=(--precomp-sea="$SEA_ZIP")
fi

echo "==> splitter $PBF -> $TILES"
java -Xmx"${JAVA_XMX}" -jar "$SPLITTER_JAR" \
  --max-threads="$MAX_JOBS" \
  --keep-complete=true \
  --max-nodes="$SPLITTER_MAX_NODES" \
  --max-areas="$SPLITTER_MAX_AREAS" \
  --output=pbf \
  --output-dir="$TILES" \
  --mapid="$MAPID" \
  --description="OSM China" \
  "${SPLIT_SEA[@]}" \
  "$PBF" \
  2>&1 | tee "$LOGS/splitter.log"

test -f "$TILES/template.args"
echo "==> 瓦片数: $(find "$TILES" -name '*.pbf' | wc -l)"
