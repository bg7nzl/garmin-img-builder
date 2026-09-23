#!/usr/bin/env bash
# 用法:
#   scripts/build.sh              # 936 + 设备图 + BaseCamp .gmap
#   CODEPAGE=65001 FAMILY_ID=4301 FAMILY_NAME="OSM China Unicode" scripts/build.sh compile
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/config.sh

ensure_deps() {
  local missing=()
  command -v java >/dev/null 2>&1 || missing+=(openjdk-17-jre-headless)
  command -v wget >/dev/null 2>&1 || missing+=(wget)
  command -v curl >/dev/null 2>&1 || missing+=(curl)
  command -v unzip >/dev/null 2>&1 || missing+=(unzip)
  command -v osmium >/dev/null 2>&1 || missing+=(osmium-tool)
  if ((${#missing[@]} == 0)); then
    return 0
  fi
  echo "==> 安装缺少的工具: ${missing[*]}"
  if ! command -v apt-get >/dev/null 2>&1 || ! command -v sudo >/dev/null 2>&1; then
    echo "请先安装这些包后再运行: ${missing[*]}" >&2
    exit 1
  fi
  sudo DEBIAN_FRONTEND=noninteractive apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}"
}

ensure_deps

stage="${1:-all}"

if [[ "$stage" == "all" ]]; then
  echo "==> 编译中国 OSM 佳明图（GBK 936）"
  echo "    本仓库只提供脚本，供学习研究。不包含、不分发地图数据或编译结果。"
  echo "    编制、公开或向他人提供中国地图须自行遵守测绘与地图管理规定。"
  echo "    首次下载约 8GB（地图数据加 DEM）。切块约 15 分钟，编译约 1–2 小时。请预留约 40GB 磁盘。"
fi

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
