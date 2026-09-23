#!/usr/bin/env python3
"""打包 BaseCamp .gmap 与设备 gmapsupp.img，上传到 s3://<bucket>/osm-build/<isotimestamp>/。"""

from __future__ import annotations

import argparse
import configparser
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path

try:
    import boto3
    from boto3.s3.transfer import TransferConfig
    from botocore.config import Config
    from botocore.exceptions import BotoCoreError, ClientError
except ImportError:
    sys.exit("缺少 boto3，先执行: pip install -r scripts/requirements-upload.txt")

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_INI = Path(__file__).resolve().parent / "upload.ini"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="打包并上传 OSM 佳明图到 S3")
    p.add_argument(
        "-c",
        "--config",
        type=Path,
        default=DEFAULT_INI,
        help=f"ini 配置（默认 {DEFAULT_INI}）",
    )
    return p.parse_args()


def load_ini(path: Path) -> configparser.ConfigParser:
    if not path.is_file():
        sys.exit(f"找不到配置文件: {path}\n可复制 scripts/upload.ini.example 为 upload.ini 后填写")
    cfg = configparser.ConfigParser()
    read = cfg.read(path, encoding="utf-8")
    if not read:
        sys.exit(f"无法读取配置文件: {path}")
    if not cfg.has_section("s3"):
        sys.exit("ini 缺少 [s3] 段")
    return cfg


def resolve_path(value: str) -> Path:
    p = Path(value).expanduser()
    if not p.is_absolute():
        p = ROOT / p
    return p.resolve()


def zip_directory(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as zf:
        for path in sorted(src.rglob("*")):
            if path.is_file():
                zf.write(path, path.relative_to(src.parent).as_posix())


def zip_file(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1) as zf:
        zf.write(src, src.name)


def s3_client(section: configparser.SectionProxy):
    kwargs = {}
    key = section.get("aws_access_key_id", fallback="").strip()
    secret = section.get("aws_secret_access_key", fallback="").strip()
    region = section.get("region", fallback="").strip()
    endpoint = section.get("endpoint_url", fallback="").strip()
    style = section.get("addressing_style", fallback="").strip()
    if not style:
        style = "path" if "r2.cloudflarestorage.com" in endpoint else "auto"
    if key:
        kwargs["aws_access_key_id"] = key
    if secret:
        kwargs["aws_secret_access_key"] = secret
    if region:
        kwargs["region_name"] = region
    elif endpoint and "r2.cloudflarestorage.com" in endpoint:
        kwargs["region_name"] = "auto"
    if endpoint:
        kwargs["endpoint_url"] = endpoint
    kwargs["config"] = Config(
        signature_version="s3v4",
        s3={"addressing_style": style},
        retries={"max_attempts": 8, "mode": "standard"},
    )
    return boto3.client("s3", **kwargs)


def upload_file(client, local: Path, bucket: str, key: str) -> None:
    cfg = TransferConfig(
        multipart_threshold=64 * 1024 * 1024,
        multipart_chunksize=64 * 1024 * 1024,
        max_concurrency=2,
    )
    print(f"上传 s3://{bucket}/{key}  ({local.stat().st_size} bytes)")
    client.upload_file(str(local), bucket, key, Config=cfg)


def main() -> int:
    args = parse_args()
    cfg = load_ini(args.config)
    s3 = cfg["s3"]
    src = cfg["source"] if cfg.has_section("source") else {}

    bucket = s3.get("bucket", fallback="").strip()
    if not bucket or bucket == "your-bucket-name":
        sys.exit("请在 ini 的 [s3] bucket 填入目标桶名")

    prefix = s3.get("prefix", fallback="osm-build").strip().strip("/")
    if not prefix:
        prefix = "osm-build"

    gmap_dir = resolve_path(src.get("gmap_dir", fallback="out/936/OSM China 936.gmap"))
    img_file = resolve_path(src.get("img_file", fallback="out/936/gmapsupp.img"))
    if not gmap_dir.is_dir():
        sys.exit(f"找不到 gmap 目录: {gmap_dir}")
    if not img_file.is_file():
        sys.exit(f"找不到 img 文件: {img_file}")

    gmap_zip_name = src.get("gmap_zip_name", fallback="gmap.zip").strip() or "gmap.zip"
    img_zip_name = src.get("img_zip_name", fallback="img.zip").strip() or "img.zip"

    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    work = ROOT / "work" / "upload" / stamp
    gmap_zip = work / gmap_zip_name
    img_zip = work / img_zip_name

    print(f"打包 {gmap_dir} -> {gmap_zip}")
    zip_directory(gmap_dir, gmap_zip)
    print(f"打包 {img_file} -> {img_zip}")
    zip_file(img_file, img_zip)

    client = s3_client(s3)
    base = f"{prefix}/{stamp}"
    try:
        upload_file(client, gmap_zip, bucket, f"{base}/{gmap_zip_name}")
        upload_file(client, img_zip, bucket, f"{base}/{img_zip_name}")
    except (BotoCoreError, ClientError) as exc:
        sys.exit(f"上传失败: {exc}")

    print(f"完成 s3://{bucket}/{base}/")
    print(f"  s3://{bucket}/{base}/{gmap_zip_name}")
    print(f"  s3://{bucket}/{base}/{img_zip_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
