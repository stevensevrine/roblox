#!/usr/bin/env python3
"""Render SchoolWar_map.csv (hasil dump_map.lua) menjadi denah top-down SVG.

Pemakaian:
    python render_map.py SchoolWar_map.csv map.svg

Hanya memakai standard library. Part kecil (< 0.4 stud) dilewati agar file
tidak membengkak. Warna asli dipertahankan, transparansi dipetakan ke opacity.
"""

import csv
import math
import sys
from pathlib import Path

MIN_SIZE = 0.4
MAX_OUTPUT = 1600


def load(path):
    rows = []
    with open(path, newline="", encoding="utf-8", errors="replace") as handle:
        for row in csv.DictReader(handle):
            try:
                row["x"] = float(row["x"])
                row["y"] = float(row["y"])
                row["z"] = float(row["z"])
                row["sx"] = float(row["sx"])
                row["sy"] = float(row["sy"])
                row["sz"] = float(row["sz"])
                row["yaw"] = float(row["yaw"] or 0)
                row["alpha"] = float(row.get("alpha") or 1)
            except (TypeError, ValueError):
                continue
            if max(row["sx"], row["sz"]) < MIN_SIZE:
                continue
            rows.append(row)
    return rows


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2]) if len(sys.argv) > 2 else src.with_suffix(".svg")
    rows = load(src)
    if not rows:
        print("Tidak ada part yang bisa dirender.")
        return 1

    min_x = min(r["x"] - max(r["sx"], r["sz"]) / 2 for r in rows)
    max_x = max(r["x"] + max(r["sx"], r["sz"]) / 2 for r in rows)
    min_z = min(r["z"] - max(r["sx"], r["sz"]) / 2 for r in rows)
    max_z = max(r["z"] + max(r["sx"], r["sz"]) / 2 for r in rows)
    span_x = max(max_x - min_x, 1)
    span_z = max(max_z - min_z, 1)
    scale = min((MAX_OUTPUT - 40) / span_x, (MAX_OUTPUT - 40) / span_z)
    width = span_x * scale + 20
    height = span_z * scale + 20

    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width:.0f}" height="{height:.0f}" '
        f'viewBox="0 0 {width:.0f} {height:.0f}">',
        f'<rect width="100%" height="100%" fill="#111318"/>',
        f'<g transform="translate({width / 2:.2f},{height / 2:.2f}) scale({scale:.4f}) '
        f'translate({-(min_x + max_x) / 2:.2f},{-(min_z + max_z) / 2:.2f})">',
    ]

    # Urutkan berdasarkan tinggi supaya part bawah tidak menimpa atap.
    rows.sort(key=lambda r: r["y"])
    for r in rows:
        rotate = r["yaw"]
        opacity = max(0.08, min(1.0, r["alpha"]))
        color = "#" + (r["color"] or "888888")
        lines.append(
            f'<rect x="{-r["sx"] / 2:.2f}" y="{-r["sz"] / 2:.2f}" '
            f'width="{r["sx"]:.2f}" height="{r["sz"]:.2f}" '
            f'fill="{color}" fill-opacity="{opacity:.2f}" '
            f'stroke="#000" stroke-opacity="{opacity * 0.25:.2f}" stroke-width="0.08" '
            f'transform="translate({r["x"]:.2f},{r["z"]:.2f}) rotate({rotate:.2f})"/>'
        )

    lines.append("</g></svg>")
    dst.write_text("\n".join(lines), encoding="utf-8")
    print(f"{len(rows)} part -> {dst} ({dst.stat().st_size} byte)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
