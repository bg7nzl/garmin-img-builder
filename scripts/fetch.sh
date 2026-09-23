#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/config.sh"

mkdir -p "$VENDOR" "$DATA/osm" "$LOGS"

# 记录上游最终地址和长度。地址变了就整文件重下，避免 wget -c 把新文件尾接到旧文件上。
fetch() {
  local url="$1" dest="$2"
  local meta="${dest}.src"
  local final len have key
  local hdr
  hdr=$(mktemp)
  final=$(curl -fsSL -I -L --retry 3 -D "$hdr" -o /dev/null -w '%{url_effective}' "$url")
  len=$(awk 'BEGIN{IGNORECASE=1} /^content-length:/ {gsub(/\r/, "", $2); n=$2} END{print n}' "$hdr")
  rm -f "$hdr"
  if [[ -z "$final" || -z "$len" ]]; then
    echo "无法取得文件地址或长度: $url" >&2
    exit 1
  fi
  key="${final} ${len}"
  have=0
  if [[ -f "$dest" ]]; then
    have=$(stat -c%s "$dest")
  fi
  if [[ -f "$dest" && "$have" == "$len" && ( ! -f "$meta" || "$(cat "$meta")" == "$key" ) ]]; then
    printf '%s\n' "$key" > "$meta"
    echo "==> 已有 $dest"
    return 0
  fi
  if [[ -f "$dest" && -f "$meta" && "$(cat "$meta")" == "$key" && "$have" -lt "$len" ]]; then
    echo "==> 续传 $final"
  else
    if [[ -f "$dest" ]]; then
      echo "==> 上游已更换或本地文件不完整，重新下载 $dest"
      rm -f "$dest"
    fi
    echo "==> $final"
  fi
  echo "    -> $dest"
  wget -c --progress=dot:giga -O "$dest" "$final"
  have=$(stat -c%s "$dest")
  if [[ "$have" != "$len" ]]; then
    echo "下载后大小是 $have 字节，上游是 $len: $dest" >&2
    exit 1
  fi
  if [[ "$dest" == *.zip ]] && ! unzip -tqq "$dest"; then
    echo "压缩包校验失败，重新下载: $dest" >&2
    rm -f "$dest"
    wget --progress=dot:giga -O "$dest" "$final"
    unzip -tqq "$dest"
  fi
  printf '%s\n' "$key" > "$meta"
}

# 3 角秒 HGT 固定 1201×1201、大端 int16。
HGT_BYTES=2884802

fetch_dem() {
  local total=0 name url zip stamp i=0 entry base sz
  local -a hgts
  mkdir -p "$DEM_HGT" "$DEM_ZIPS" "$DEM_OK"
  total=$(grep -cE '^[A-Z]+[0-9]+$' "$VIEWFINDER_LIST")
  while read -r name; do
    [[ "$name" =~ ^[A-Z]+[0-9]+$ ]] || continue
    i=$((i + 1))
    stamp="$DEM_OK/$name"
    if [[ -f "$stamp" ]]; then
      echo "==> DEM $i/$total $name 已有"
      continue
    fi
    url="${VIEWFINDER_BASE}/${name}.zip"
    zip="$DEM_ZIPS/${name}.zip"
    echo "==> DEM $i/$total $url"
    wget -c --progress=dot:giga -O "$zip" "$url"
    unzip -qo -j "$zip" '*.hgt' -d "$DEM_HGT"
    mapfile -t hgts < <(unzip -Z1 "$zip" '*.hgt')
    if ((${#hgts[@]} == 0)); then
      echo "压缩包里没有 .hgt: $zip" >&2
      exit 1
    fi
    for entry in "${hgts[@]}"; do
      base=$(basename "$entry")
      sz=$(stat -c%s "$DEM_HGT/$base")
      if [[ "$sz" != "$HGT_BYTES" ]]; then
        echo "$base 大小是 $sz 字节，不是 3 角秒 HGT（$HGT_BYTES）" >&2
        rm -f "$DEM_HGT/$base"
        exit 1
      fi
    done
    rm -f "$zip"
    touch "$stamp"
    echo "    ${#hgts[@]} 块"
  done < "$VIEWFINDER_LIST"
  if [[ "$i" != "$total" ]]; then
    echo "DEM 清单处理了 $i 行，期望 $total" >&2
    exit 1
  fi
}

if [[ ! -f "$MKGMAP_JAR" ]]; then
  fetch "$MKGMAP_URL" "$VENDOR/mkgmap-${MKGMAP_VER}.zip"
  unzip -qo "$VENDOR/mkgmap-${MKGMAP_VER}.zip" -d "$VENDOR"
fi
if [[ ! -f "$SPLITTER_JAR" ]]; then
  fetch "$SPLITTER_URL" "$VENDOR/splitter-${SPLITTER_VER}.zip"
  unzip -qo "$VENDOR/splitter-${SPLITTER_VER}.zip" -d "$VENDOR"
fi

fetch_border() {
  local zip="$BORDER_DIR/china-geospatial-data-UTF8.zip"
  mkdir -p "$BORDER_DIR"
  fetch "$BORDER_ZIP_URL" "$zip"
  unzip -qo "$zip" -d "$BORDER_DIR"
  local src="$BORDER_DIR/china-geospatial-data-UTF8"
  python3 "$ROOT/scripts/border.py" \
    --border "$src/CN-border-L1.gmt" \
    --dash "$src/ten-dash-line.gmt" \
    --poly "$CLAIM_POLY" \
    --dem-poly "$DEM_POLY" \
    --osm "$BORDER_OSM"
  echo "==> 国界 OSM -> $BORDER_PBF"
  osmium sort --overwrite -o "$BORDER_PBF" "$BORDER_OSM"
}

fetch "$PBF_URL" "$PBF"
fetch "$TAIWAN_PBF_URL" "$TAIWAN_PBF"
fetch "$INDIA_EAST_PBF_URL" "$INDIA_EAST_PBF"
fetch "$INDIA_NORTH_PBF_URL" "$INDIA_NORTH_PBF"
fetch "$INDIA_NORTHEAST_PBF_URL" "$INDIA_NORTHEAST_PBF"
fetch "$BHUTAN_PBF_URL" "$BHUTAN_PBF"
fetch "$SEA_URL" "$SEA_ZIP"
fetch "$BOUNDS_URL" "$BOUNDS_ZIP"
fetch_border
fetch_dem

echo "==> 下载完成"
ls -lh "$PBF" "$TAIWAN_PBF" "$INDIA_EAST_PBF" "$INDIA_NORTH_PBF" "$INDIA_NORTHEAST_PBF" "$BHUTAN_PBF" \
  "$SEA_ZIP" "$BOUNDS_ZIP" "$CLAIM_POLY" "$BORDER_PBF" "$MKGMAP_JAR" "$SPLITTER_JAR"
echo "==> DEM $(find "$DEM_HGT" -name '*.hgt' | wc -l) 块，$(du -sh "$DEM_HGT" | awk '{print $1}')"
