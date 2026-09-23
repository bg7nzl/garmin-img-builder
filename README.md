# 中国 OSM 佳明地图

在 Ubuntu 上一条命令编出两份地图：佳明设备用的 `gmapsupp.img`，以及 BaseCamp 用的 `.gmap`。

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

## 编完后怎么用

| 文件 | 放到哪里 |
| --- | --- |
| `out/936/gmapsupp.img` | 佳明 SD 卡的 `Garmin/` 目录 |
| `out/936/OSM China 936.gmap/` | BaseCamp：`C:\ProgramData\Garmin\Maps\` |

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

产物在 `out/65001/`。

## 上传（可选）

把 `scripts/upload.ini.example` 复制为 `scripts/upload.ini` 并填写桶信息，然后：

```bash
pip install -r scripts/requirements-upload.txt
python3 scripts/upload_s3.py
```

`upload.ini` 含密钥，不要提交到 git。
