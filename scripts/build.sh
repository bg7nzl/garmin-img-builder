#!/usr/bin/env bash
# 用法:
#   scripts/build.sh              # 936 + 设备图 + BaseCamp .gmap
#   CODEPAGE=65001 FAMILY_ID=4301 FAMILY_NAME="OSM China Unicode" scripts/build.sh compile
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/config.sh

stage="${1:-all}"

case "$stage" in
  fetch)   exec scripts/fetch.sh ;;
  split)   exec scripts/split.sh ;;
  compile) exec scripts/compile.sh ;;
  all)
    scripts/fetch.sh
    scripts/split.sh
    scripts/compile.sh
    ;;
  *)
    echo "用法: $0 [fetch|split|compile|all]" >&2
    exit 2
    ;;
esac
