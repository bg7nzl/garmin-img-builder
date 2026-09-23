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

dem_expected=$(grep -cE '^[A-Z]+[0-9]+$' "$VIEWFINDER_LIST")
dem_ready=0
if [[ -d "$DEM_OK" ]]; then
  dem_ready=$(find "$DEM_OK" -type f | wc -l)
fi
if [[ "$dem_ready" -lt "$dem_expected" || ! -d "$DEM_HGT" ]]; then
  echo "DEM 未下完（$dem_ready/$dem_expected），先跑 scripts/fetch.sh" >&2
  exit 1
fi
if [[ ! -f "$DEM_POLY" ]]; then
  echo "缺少 $DEM_POLY，先跑 scripts/fetch.sh" >&2
  exit 1
fi
EXTRA+=(--dem="$DEM_HGT")
EXTRA+=(--dem-dists="$DEM_DISTS")
EXTRA+=(--dem-poly="$DEM_POLY")
EXTRA+=(--overview-dem-dist="$OVERVIEW_DEM_DIST")

if [[ "$CODEPAGE" == "65001" ]]; then
  CP_ARGS=(--unicode --code-page=65001)
else
  CP_ARGS=(--code-page="$CODEPAGE")
fi

echo "==> mkgmap codepage=$CODEPAGE family-id=$FAMILY_ID -> $OUT"
echo "==> DEM $(find "$DEM_HGT" -name '*.hgt' | wc -l) 块, dists=$DEM_DISTS, overview=$OVERVIEW_DEM_DIST"
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
  --region-name=中国 \
  --region-abbr=CHN \
  --overview-mapname="$OVERVIEW_NAME" \
  --description="$FAMILY_NAME" \
  --draw-priority=10 \
  --remove-ovm-work-files \
  --keep-going \
  "${EXTRA[@]}" \
  "$ROOT/styles/osm-china/osm-china.txt" \
  -c "$TILES/template.args" \
  2>&1 | tee "$LOGS/mkgmap-${CODEPAGE}.log"

# 设备叠图看 TRE 偏移 0x44。mkgmap 把这个字节固定写成 3，--draw-priority 只写 0x40。
# 改成 2 之后，0x44 为 3 的等高线会盖在这张图上面。
echo "==> TRE 图层字节 0x44 = 2"
python3 - "$OUT" << 'PY'
import struct
import sys
from pathlib import Path

root = Path(sys.argv[1])
changed = 0
files = 0

def patch(path):
    global changed
    with open(path, "r+b") as f:
        hdr = f.read(0x63)
        if len(hdr) < 0x63 or hdr[0x10:0x16] != b"DSKIMG" or hdr[0] != 0:
            return
        block = 1 << (hdr[0x61] + hdr[0x62])
        dir_off = hdr[0x40] * 512
        for i in range(100000):
            f.seek(dir_off + i * 512)
            ent = f.read(0x22)
            if len(ent) < 0x22 or ent[0] != 1:
                break
            if ent[9:12] != b"TRE" or ent[0x11] != 0:
                continue
            phys = struct.unpack_from("<H", ent, 0x20)[0] * block
            f.seek(phys + 2)
            if f.read(10) != b"GARMIN TRE":
                raise SystemExit(f"TRE 头不对: {path} @ {phys}")
            f.seek(phys + 0x44)
            if f.read(1) != b"\x03":
                continue
            f.seek(phys + 0x44)
            f.write(b"\x02")
            changed += 1

for path in sorted(root.rglob("*.img")):
    files += 1
    patch(path)
print(f"0x44: {changed} 个 TRE，{files} 个 img")
PY

echo "==> 产物"
ls -lh "$OUT/gmapsupp.img" 2>/dev/null || true
find "$OUT" -maxdepth 2 -name '*.gmap' -o -name 'Info.xml' | head
echo "==> 设备: 复制 $OUT/gmapsupp.img -> SD/Garmin/"
echo "==> BaseCamp Windows: 复制 $OUT/${FAMILY_NAME}.gmap -> C:\\ProgramData\\Garmin\\Maps\\"
