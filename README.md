# 中国 OSM 佳明地图

在 Ubuntu 上可以用一条命令在本机编出两份地图：佳明设备用的 `gmapsupp.img`，以及 BaseCamp 用的 `.gmap`。

## 免责声明

本仓库只提供构建脚本和地图样式，供学习、研究佳明地图的编译流程。

仓库不包含、不托管、不分发任何地图数据或编译结果（包括 OSM PBF、`gmapsupp.img`、`.gmap`）。这些文件只应留在你自己的机器上。

使用 OpenStreetMap 编制中国地图，以及展示、出版或向他人提供该地图，受《中华人民共和国测绘法》《地图管理条例》等规定约束。使用者须自行遵守适用法律，并在需要时取得地图审核和相应资质。作者不提供地图成果，不对编译、使用或传播行为承担责任。

## 一键编译

```bash
./build.sh
```

脚本会在缺少 Java、`wget` 或 `unzip` 时用 apt 安装（可能要求输入 sudo 密码），然后下载数据并编译。mkgmap 和 splitter 由脚本自己下载，不用单独安装。

第一次大约要数小时：下载约 4GB（视网速而定），切块约 15 分钟，编译约 1 小时。请预留约 30GB 磁盘。默认按 2 核、8GB 内存设置（Java 堆 3GB、并行 2）。机器更大时可以加大，例如：

```bash
JAVA_XMX=6g MAX_JOBS=4 ./build.sh
```

中断后直接再跑同一条命令即可。下载支持续传；切块和编译会从头再做。

## 本机产物

编译结果写在本机的 `out/`，不进入本仓库，也不由本仓库分发。

| 文件 | 位置 |
| --- | --- |
| `out/936/gmapsupp.img` | 设备图 |
| `out/936/OSM China 936.gmap/` | BaseCamp 图 |

图名是 **OSM China 936**，使用 GBK 字库，可以显示中文。

## 只重跑某一步

```bash
./build.sh fetch     # 只下载
./build.sh split     # 只切块
./build.sh compile   # 只编译
```

换 Unicode 字库不用重新下载和切块：

```bash
CODEPAGE=65001 FAMILY_ID=4301 FAMILY_NAME="OSM China Unicode" ./build.sh compile
```

产物在 `out/65001/`，同样只留在本机。
