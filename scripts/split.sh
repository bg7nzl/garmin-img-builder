#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

if [[ ! -f "$PBF" ]]; then
  echo "缺少 $PBF，先跑 scripts/fetch.sh" >&2
  exit 1
fi
if [[ ! -f "$TAIWAN_PBF" || ! -f "$INDIA_EAST_PBF" || ! -f "$INDIA_NORTH_PBF" || ! -f "$INDIA_NORTHEAST_PBF" || ! -f "$BHUTAN_PBF" ]]; then
  echo "缺少台湾、印度东部、印度北部、印度东北部或不丹数据，先跑 scripts/fetch.sh" >&2
  exit 1
fi
if [[ ! -f "$CLAIM_POLY" || ! -f "$BORDER_PBF" ]]; then
  echo "缺少国界 $CLAIM_POLY 或 $BORDER_PBF，先跑 scripts/fetch.sh" >&2
  exit 1
fi
if [[ ! -f "$SPLITTER_JAR" ]]; then
  echo "缺少 $SPLITTER_JAR，先跑 scripts/fetch.sh" >&2
  exit 1
fi
if ! command -v osmium >/dev/null 2>&1; then
  echo "缺少 osmium，请安装 osmium-tool" >&2
  exit 1
fi

SOURCES="$WORK/china-sources.osm.pbf"
CLIPPED="$WORK/china-claim.osm.pbf"
MERGED="$WORK/china-merged.osm.pbf"
mkdir -p "$WORK" "$LOGS"
echo "==> osmium merge 中国、台湾、藏南一侧、不丹"
osmium merge --overwrite --progress -o "$SOURCES" \
  "$PBF" "$TAIWAN_PBF" "$INDIA_EAST_PBF" "$INDIA_NORTH_PBF" "$INDIA_NORTHEAST_PBF" "$BHUTAN_PBF"
echo "==> 按国界多边形裁剪 -> $CLIPPED"
osmium extract --overwrite --strategy smart -p "$CLAIM_POLY" "$SOURCES" -o "$CLIPPED"
echo "==> 并入国界线和十段线 -> $MERGED"
osmium merge --overwrite --progress -o "$MERGED" "$CLIPPED" "$BORDER_PBF"

rm -rf "$TILES"
mkdir -p "$TILES"

SPLIT_SEA=()
if [[ -f "$SEA_ZIP" ]]; then
  SPLIT_SEA=(--precomp-sea="$SEA_ZIP")
fi

echo "==> splitter $MERGED -> $TILES"
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
  "$MERGED" \
  2>&1 | tee "$LOGS/splitter.log"

test -f "$TILES/template.args"
echo "==> 瓦片数: $(find "$TILES" -name '*.pbf' | wc -l)"
