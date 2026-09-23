# 中国 OSM → 佳明（设备 gmapsupp + BaseCamp .gmap）
# 换编码只需改 CODEPAGE / FAMILY_ID / FAMILY_NAME 后重跑 compile。

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REGION="${REGION:-china}"
# 2312/GBK 字库：936；Unicode：65001
CODEPAGE="${CODEPAGE:-936}"
FAMILY_ID="${FAMILY_ID:-4300}"
FAMILY_NAME="${FAMILY_NAME:-OSM China 936}"
SERIES_NAME="${SERIES_NAME:-OSM China}"
MAPID="${MAPID:-63240001}"
OVERVIEW_NAME="${OVERVIEW_NAME:-osmchina}"

JAVA_XMX="${JAVA_XMX:-3g}"
MAX_JOBS="${MAX_JOBS:-2}"
SPLITTER_MAX_NODES="${SPLITTER_MAX_NODES:-1200000}"
SPLITTER_MAX_AREAS="${SPLITTER_MAX_AREAS:-512}"

MKGMAP_VER="${MKGMAP_VER:-r4924}"
SPLITTER_VER="${SPLITTER_VER:-r654}"

VENDOR="$ROOT/vendor"
DATA="$ROOT/data"
WORK="$ROOT/work"
OUT="$ROOT/out/${CODEPAGE}"
LOGS="$ROOT/logs"
TILES="$WORK/tiles"

PBF_URL="${PBF_URL:-https://download.geofabrik.de/asia/china-latest.osm.pbf}"
PBF="$DATA/osm/china-latest.osm.pbf"
BOUNDS_ZIP="$DATA/bounds-latest.zip"
SEA_ZIP="$DATA/sea-latest.zip"
BOUNDS_URL="${BOUNDS_URL:-https://www.thkukuk.de/osm/data/bounds-latest.zip}"
SEA_URL="${SEA_URL:-https://www.thkukuk.de/osm/data/sea-latest.zip}"
MKGMAP_URL="https://www.mkgmap.org.uk/download/mkgmap-${MKGMAP_VER}.zip"
SPLITTER_URL="https://www.mkgmap.org.uk/download/splitter-${SPLITTER_VER}.zip"

MKGMAP_JAR="$VENDOR/mkgmap-${MKGMAP_VER}/mkgmap.jar"
SPLITTER_JAR="$VENDOR/splitter-${SPLITTER_VER}/splitter.jar"

export ROOT REGION CODEPAGE FAMILY_ID FAMILY_NAME SERIES_NAME MAPID OVERVIEW_NAME
export JAVA_XMX MAX_JOBS SPLITTER_MAX_NODES SPLITTER_MAX_AREAS
export VENDOR DATA WORK OUT LOGS TILES
export PBF PBF_URL BOUNDS_ZIP SEA_ZIP BOUNDS_URL SEA_URL
export MKGMAP_JAR SPLITTER_JAR MKGMAP_URL SPLITTER_URL MKGMAP_VER SPLITTER_VER
