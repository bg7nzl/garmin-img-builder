#!/usr/bin/env python3
"""把 CN-border 收成切图用的 .poly，以及给 mkgmap 画的国界 OSM。

CN-border-L1 里闭合环是国土轮廓（含台湾、藏南、阿克赛钦、钓鱼岛、南海岛礁）。
不闭合的线段里混有十段线，十段线改从 ten-dash-line.gmt 单独读入，避免把岛礁碎线当成国境。
"""

from __future__ import annotations

import argparse
from pathlib import Path


def read_gmt(path: Path) -> list[list[tuple[float, float]]]:
    segs: list[list[tuple[float, float]]] = []
    cur: list[tuple[float, float]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#") or line.startswith("@") or line.startswith("FEATURE"):
            continue
        if line.startswith(">"):
            if cur:
                segs.append(cur)
            cur = []
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        try:
            cur.append((float(parts[0]), float(parts[1])))
        except ValueError:
            continue
    if cur:
        segs.append(cur)
    return segs


def is_closed(seg: list[tuple[float, float]]) -> bool:
    if len(seg) < 4:
        return False
    a, b = seg[0], seg[-1]
    return abs(a[0] - b[0]) < 1e-6 and abs(a[1] - b[1]) < 1e-6


def _dist(p, a, b) -> float:
    (x, y), (x1, y1), (x2, y2) = p, a, b
    dx, dy = x2 - x1, y2 - y1
    if dx == 0 and dy == 0:
        return ((x - x1) ** 2 + (y - y1) ** 2) ** 0.5
    t = max(0.0, min(1.0, ((x - x1) * dx + (y - y1) * dy) / (dx * dx + dy * dy)))
    px, py = x1 + t * dx, y1 + t * dy
    return ((x - px) ** 2 + (y - py) ** 2) ** 0.5


def simplify(pts: list[tuple[float, float]], eps: float) -> list[tuple[float, float]]:
    n = len(pts)
    if n < 3:
        return pts
    keep = [False] * n
    keep[0] = keep[-1] = True
    stack = [(0, n - 1)]
    while stack:
        i, j = stack.pop()
        dmax = 0.0
        idx = i
        a, b = pts[i], pts[j]
        for k in range(i + 1, j):
            d = _dist(pts[k], a, b)
            if d > dmax:
                dmax = d
                idx = k
        if dmax > eps:
            keep[idx] = True
            stack.append((i, idx))
            stack.append((idx, j))
    return [p for p, flag in zip(pts, keep) if flag]


def ring_name(seg: list[tuple[float, float]]) -> str | None:
    xs = [p[0] for p in seg]
    ys = [p[1] for p in seg]
    # 这两个小岛各自只有一个闭合环，用范围对上名字。
    if 123.50 <= min(xs) and max(xs) <= 123.56 and 25.74 <= min(ys) and max(ys) <= 25.79:
        return "钓鱼岛"
    if 123.68 <= min(xs) and max(xs) <= 123.72 and 25.92 <= min(ys) and max(ys) <= 25.95:
        return "黄尾屿"
    return None


def write_poly(rings: list[list[tuple[float, float]]], dest: Path, name: str = "claim") -> None:
    lines = [name]
    for n, ring in enumerate(rings, start=1):
        lines.append(str(n))
        for lon, lat in ring:
            lines.append(f"   {lon:.7f}   {lat:.7f}")
        lines.append("END")
    lines.append("END")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_osm(ways: list[tuple[list[tuple[float, float]], str, str | None]], dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    nid = 8_000_000_000_001
    wid = 8_100_000_000_001
    with dest.open("w", encoding="utf-8") as out:
        out.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        out.write('<osm version="0.6" generator="cn-border">\n')
        for coords, source, name in ways:
            ids = []
            for lon, lat in coords:
                out.write(f'  <node id="{nid}" lat="{lat:.7f}" lon="{lon:.7f}"/>\n')
                ids.append(nid)
                nid += 1
            out.write(f'  <way id="{wid}">\n')
            for ref in ids:
                out.write(f'    <nd ref="{ref}"/>\n')
            out.write('    <tag k="boundary" v="administrative"/>\n')
            out.write('    <tag k="admin_level" v="2"/>\n')
            out.write(f'    <tag k="source" v="{source}"/>\n')
            if name:
                out.write(f'    <tag k="name" v="{name}"/>\n')
                out.write(f'    <tag k="mkgmap:boundary_name" v="{name}"/>\n')
            out.write("  </way>\n")
            wid += 1
        out.write("</osm>\n")


def chunk(coords: list[tuple[float, float]], size: int) -> list[list[tuple[float, float]]]:
    if len(coords) <= size:
        return [coords]
    pieces = []
    i = 0
    while i < len(coords) - 1:
        piece = coords[i : i + size]
        if len(piece) < 2:
            break
        pieces.append(piece)
        i += size - 1
    return pieces


def _inside(poly: list[tuple[float, float]], x: float, y: float) -> bool:
    n = len(poly)
    c = False
    j = n - 1
    for i in range(n):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi or 1e-30) + xi):
            c = not c
        j = i
    return c


def dem_coverage(closed: list[list[tuple[float, float]]], cell: float = 0.09) -> list[list[tuple[float, float]]]:
    """DEM 范围用约 10km 的格子盖住国土，再向外扩一格。

    格子大约 0.09°（纬度方向约 10km）。边界所在的格子算在内，再向八邻域扩一格，
    所以国界外大约 10–20km 仍有高程。抽稀后的切图多边形仍然用细边界，不走这里。
    """
    import math
    from collections import deque

    def key(lon: float, lat: float) -> tuple[int, int]:
        return math.floor(lon / cell), math.floor(lat / cell)

    marked: set[tuple[int, int]] = set()
    for seg in closed:
        body = seg[:-1] if seg[0] == seg[-1] else list(seg)
        if len(body) < 3:
            continue
        if len(body) > 8000:
            body = simplify(body, 0.02)
        boundary: set[tuple[int, int]] = set()
        prev = None
        for (x1, y1), (x2, y2) in zip(body, body[1:] + body[:1]):
            steps = int(max(abs(x2 - x1), abs(y2 - y1)) / (cell * 0.25)) + 1
            for s in range(steps + 1):
                t = s / steps
                cur = key(x1 + (x2 - x1) * t, y1 + (y2 - y1) * t)
                if prev is not None and abs(cur[0] - prev[0]) == 1 and abs(cur[1] - prev[1]) == 1:
                    boundary.add((prev[0], cur[1]))
                    boundary.add((cur[0], prev[1]))
                boundary.add(cur)
                prev = cur
        marked |= boundary
        xs = [ix for ix, _ in boundary]
        ys = [iy for _, iy in boundary]
        x0, x1 = min(xs) - 1, max(xs) + 1
        y0, y1 = min(ys) - 1, max(ys) + 1
        seed = None
        for lon, lat in body[:: max(1, len(body) // 30)]:
            ix, iy = key(lon, lat)
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                sx, sy = ix + dx, iy + dy
                cx, cy = (sx + 0.5) * cell, (sy + 0.5) * cell
                if (sx, sy) not in boundary and _inside(body, cx, cy):
                    seed = (sx, sy)
                    break
            if seed:
                break
        if seed is None:
            continue
        q = deque([seed])
        seen = {seed}
        while q:
            ix, iy = q.popleft()
            if not (x0 <= ix <= x1 and y0 <= iy <= y1) or (ix, iy) in boundary:
                continue
            marked.add((ix, iy))
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                nxt = (ix + dx, iy + dy)
                if nxt in seen or nxt in boundary:
                    continue
                seen.add(nxt)
                q.append(nxt)

    grown: set[tuple[int, int]] = set(marked)
    for ix, iy in marked:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                grown.add((ix + dx, iy + dy))

    seen_comp: set[tuple[int, int]] = set()
    rings: list[list[tuple[float, float]]] = []
    for start in grown:
        if start in seen_comp:
            continue
        comp: list[tuple[int, int]] = []
        q = deque([start])
        seen_comp.add(start)
        while q:
            cur = q.popleft()
            comp.append(cur)
            ix, iy = cur
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nxt = (ix + dx, iy + dy)
                if nxt in grown and nxt not in seen_comp:
                    seen_comp.add(nxt)
                    q.append(nxt)
        rings.append(_cell_ring(comp, cell))
    return [r for r in rings if len(r) >= 4]


def _cell_ring(cells: list[tuple[int, int]], cell: float) -> list[tuple[float, float]]:
    occupied = set(cells)
    edges: dict[tuple[float, float], tuple[float, float]] = {}

    def corner(ix: int, iy: int) -> tuple[float, float]:
        return (round(ix * cell, 6), round(iy * cell, 6))

    for ix, iy in cells:
        sides = (
            ((ix, iy), (ix + 1, iy), (ix, iy - 1)),
            ((ix + 1, iy), (ix + 1, iy + 1), (ix + 1, iy)),
            ((ix + 1, iy + 1), (ix, iy + 1), (ix, iy + 1)),
            ((ix, iy + 1), (ix, iy), (ix - 1, iy)),
        )
        for a, b, neighbor in sides:
            if neighbor in occupied:
                continue
            edges[corner(*a)] = corner(*b)
    if not edges:
        return []
    remaining = dict(edges)
    loops: list[list[tuple[float, float]]] = []
    while remaining:
        start = next(iter(remaining))
        ring = [start]
        cur = start
        while cur in remaining:
            nxt = remaining.pop(cur)
            ring.append(nxt)
            if nxt == start:
                break
            cur = nxt
        if len(ring) >= 4 and ring[0] == ring[-1]:
            loops.append(ring)
    if not loops:
        return []

    def area(ring: list[tuple[float, float]]) -> float:
        acc = 0.0
        for (x1, y1), (x2, y2) in zip(ring, ring[1:]):
            acc += x1 * y2 - x2 * y1
        return abs(acc)

    simplified = simplify(max(loops, key=area), cell * 0.6)
    if simplified[0] != simplified[-1]:
        simplified.append(simplified[0])
    return simplified


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--border", type=Path, required=True)
    parser.add_argument("--dash", type=Path, required=True)
    parser.add_argument("--poly", type=Path, required=True)
    parser.add_argument("--osm", type=Path, required=True)
    parser.add_argument("--dem-poly", type=Path)
    parser.add_argument("--epsilon", type=float, default=0.002)
    args = parser.parse_args()

    closed = [seg for seg in read_gmt(args.border) if is_closed(seg)]
    if not closed:
        raise SystemExit(f"没有闭合国界环: {args.border}")

    clip_rings = []
    for seg in closed:
        body = seg[:-1]
        if len(seg) > 20000:
            body = simplify(body, args.epsilon)
        body.append(body[0])
        clip_rings.append(body)
    write_poly(clip_rings, args.poly)
    if args.dem_poly:
        dem_src = list(closed)
        for seg in read_gmt(args.border):
            if is_closed(seg) or len(seg) < 4:
                continue
            a, b = seg[0], seg[-1]
            if abs(a[0] - b[0]) < 0.005 and abs(a[1] - b[1]) < 0.005:
                dem_src.append(seg + [seg[0]])
        dem = dem_coverage(dem_src)
        write_poly(dem, args.dem_poly, name="dem")
        pts = sum(len(r) for r in dem)
        print(f"DEM 范围 {len(dem)} 环、{pts} 点，写入 {args.dem_poly}")

    draw: list[tuple[list[tuple[float, float]], str, str | None]] = []
    for seg in closed:
        label = ring_name(seg)
        for piece in chunk(seg, 1400):
            draw.append((piece, "cn-border", label))
            label = None
    for seg in read_gmt(args.dash):
        if len(seg) < 2:
            continue
        for piece in chunk(seg, 1400):
            draw.append((piece, "cn-dash", None))
    write_osm(draw, args.osm)
    print(f"闭合环 {len(closed)}，切图环已写入 {args.poly}")
    print(f"国界线 {len(draw)} 段，写入 {args.osm}")


if __name__ == "__main__":
    main()
