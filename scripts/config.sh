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
TAIWAN_PBF_URL="${TAIWAN_PBF_URL:-https://download.geofabrik.de/asia/taiwan-latest.osm.pbf}"
TAIWAN_PBF="$DATA/osm/taiwan-latest.osm.pbf"
INDIA_EAST_PBF_URL="${INDIA_EAST_PBF_URL:-https://download.geofabrik.de/asia/india/eastern-zone-latest.osm.pbf}"
INDIA_EAST_PBF="$DATA/osm/india-eastern-zone-latest.osm.pbf"
INDIA_NORTH_PBF_URL="${INDIA_NORTH_PBF_URL:-https://download.geofabrik.de/asia/india/northern-zone-latest.osm.pbf}"
INDIA_NORTH_PBF="$DATA/osm/india-northern-zone-latest.osm.pbf"
INDIA_NORTHEAST_PBF_URL="${INDIA_NORTHEAST_PBF_URL:-https://download.geofabrik.de/asia/india/north-eastern-zone-latest.osm.pbf}"
INDIA_NORTHEAST_PBF="$DATA/osm/india-north-eastern-zone-latest.osm.pbf"
BHUTAN_PBF_URL="${BHUTAN_PBF_URL:-https://download.geofabrik.de/asia/bhutan-latest.osm.pbf}"
BHUTAN_PBF="$DATA/osm/bhutan-latest.osm.pbf"
BOUNDS_ZIP="$DATA/bounds-latest.zip"
SEA_ZIP="$DATA/sea-latest.zip"
BOUNDS_URL="${BOUNDS_URL:-https://www.thkukuk.de/osm/data/bounds-latest.zip}"
SEA_URL="${SEA_URL:-https://www.thkukuk.de/osm/data/sea-latest.zip}"

# Viewfinder Panoramas 3"（约 90 米）HGT。样式 levels 有 4 级，DEM 间距与之对应。
# 国界用 CN-border（1:100 万基础地理数据库），不用 Geofabrik / OSM 的国界。
DEM_HGT="$DATA/dem/hgt"
DEM_ZIPS="$DATA/dem/zips"
DEM_OK="$DATA/dem/ok"
CHINA_POLY="$DATA/china.poly"
TAIWAN_POLY="$DATA/taiwan.poly"
BORDER_DIR="$DATA/border"
BORDER_ZIP_URL="${BORDER_ZIP_URL:-https://github.com/gmt-china/china-geospatial-data/releases/download/v0.4.0/china-geospatial-data-UTF8.zip}"
CLAIM_POLY="$BORDER_DIR/claim.poly"
BORDER_OSM="$BORDER_DIR/cn-border.osm"
BORDER_PBF="$BORDER_DIR/cn-border.osm.pbf"
DEM_POLY="$BORDER_DIR/dem.poly"
POLY_URL="${POLY_URL:-https://download.geofabrik.de/asia/china.poly}"
TAIWAN_POLY_URL="${TAIWAN_POLY_URL:-https://download.geofabrik.de/asia/taiwan.poly}"
VIEWFINDER_BASE="${VIEWFINDER_BASE:-https://viewfinderpanoramas.org/dem3}"
VIEWFINDER_LIST="$ROOT/scripts/viewfinder-china.txt"
DEM_DISTS="${DEM_DISTS:-9942,19884,39768,79536}"
OVERVIEW_DEM_DIST="${OVERVIEW_DEM_DIST:-159072}"
MKGMAP_URL="https://www.mkgmap.org.uk/download/mkgmap-${MKGMAP_VER}.zip"
SPLITTER_URL="https://www.mkgmap.org.uk/download/splitter-${SPLITTER_VER}.zip"

MKGMAP_JAR="$VENDOR/mkgmap-${MKGMAP_VER}/mkgmap.jar"
SPLITTER_JAR="$VENDOR/splitter-${SPLITTER_VER}/splitter.jar"

export ROOT REGION CODEPAGE FAMILY_ID FAMILY_NAME SERIES_NAME MAPID OVERVIEW_NAME
export JAVA_XMX MAX_JOBS SPLITTER_MAX_NODES SPLITTER_MAX_AREAS
export VENDOR DATA WORK OUT LOGS TILES
export PBF PBF_URL TAIWAN_PBF TAIWAN_PBF_URL
export INDIA_EAST_PBF INDIA_EAST_PBF_URL INDIA_NORTH_PBF INDIA_NORTH_PBF_URL
export INDIA_NORTHEAST_PBF INDIA_NORTHEAST_PBF_URL
export BHUTAN_PBF BHUTAN_PBF_URL
export BOUNDS_ZIP SEA_ZIP BOUNDS_URL SEA_URL
export DEM_HGT DEM_ZIPS DEM_OK CHINA_POLY TAIWAN_POLY
export BORDER_DIR BORDER_ZIP_URL CLAIM_POLY BORDER_OSM BORDER_PBF
export DEM_POLY POLY_URL TAIWAN_POLY_URL
export VIEWFINDER_BASE VIEWFINDER_LIST
export DEM_DISTS OVERVIEW_DEM_DIST
export MKGMAP_JAR SPLITTER_JAR MKGMAP_URL SPLITTER_URL MKGMAP_VER SPLITTER_VER
