#!/usr/bin/env bash
# 编出：
#   out/<codepage>/gmapsupp.img          拷到设备 SD/Garmin/
#   out/<codepage>/<family-name>.gmap/   拷到 BaseCamp:
#       Windows: C:\ProgramData\Garmin\Maps\
#       或 %APPDATA%\Garmin\Maps\
set -euo pipefail
source "$(dirname "$0")/config.sh"

if [[ ! -f "$TILES/template.args" ]]; then
  echo "缺少 $TILES/template.args，先跑 scripts/split.sh" >&2
  exit 1
fi
if [[ ! -f "$MKGMAP_JAR" ]]; then
  echo "缺少 $MKGMAP_JAR，先跑 scripts/fetch.sh" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$OUT" "$LOGS"

EXTRA=()
if [[ -f "$BOUNDS_ZIP" ]]; then
  EXTRA+=(--bounds="$BOUNDS_ZIP")
  EXTRA+=(--location-autofill=is_in,nearest)
  EXTRA+=(--housenumbers)
fi
if [[ -f "$SEA_ZIP" ]]; then
  EXTRA+=(--precomp-sea="$SEA_ZIP" --generate-sea)
fi

if [[ "$CODEPAGE" == "65001" ]]; then
  CP_ARGS=(--unicode --code-page=65001)
else
  CP_ARGS=(--code-page="$CODEPAGE")
fi

echo "==> mkgmap codepage=$CODEPAGE family-id=$FAMILY_ID -> $OUT"
echo "==> 设备: gmapsupp.img ; BaseCamp: ${FAMILY_NAME}.gmap"

# template.args 里的 input-file 是相对路径，必须在瓦片目录里跑。
cd "$TILES"

# 选项顺序有意义：全局选项在 -c template.args 之前。
# --gmapi 已隐含 --tdbfile。同时出 gmapsupp（手持机）和 .gmap（BaseCamp）。
java -Xmx"${JAVA_XMX}" -jar "$MKGMAP_JAR" \
  --max-jobs="$MAX_JOBS" \
  --output-dir="$OUT" \
  --gmapsupp \
  --gmapi \
  --index \
  --route \
  --drive-on=right \
  --process-destination \
  --process-exits \
  --add-pois-to-areas \
  --pois-to-areas-placement="entrance=main;entrance=shop;entrance=yes;entrance=home;building=entrance;amenity=parking_entrance;entrance=*" \
  --poi-address \
  --link-pois-to-ways \
  --nearby-poi-rules="*/named:10,*/unnamed:25" \
  --style-file="$ROOT/styles/osm-china" \
  "${CP_ARGS[@]}" \
  --family-id="$FAMILY_ID" \
  --family-name="$FAMILY_NAME" \
  --series-name="$SERIES_NAME" \
  --area-name="China" \
  --country-name="China" \
  --country-abbr=CHN \
  --overview-mapname="$OVERVIEW_NAME" \
  --description="$FAMILY_NAME" \
  --remove-ovm-work-files \
  --keep-going \
  "${EXTRA[@]}" \
  -c "$TILES/template.args" \
  2>&1 | tee "$LOGS/mkgmap-${CODEPAGE}.log"

echo "==> 产物"
ls -lh "$OUT/gmapsupp.img" 2>/dev/null || true
find "$OUT" -maxdepth 2 -name '*.gmap' -o -name 'Info.xml' | head
echo "==> 设备: 复制 $OUT/gmapsupp.img -> SD/Garmin/"
echo "==> BaseCamp Windows: 复制 $OUT/${FAMILY_NAME}.gmap -> C:\\ProgramData\\Garmin\\Maps\\"
