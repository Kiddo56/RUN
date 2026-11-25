#!/usr/bin/env python3
"""
Deterministic, zero-dependency app icon and asset catalog generator for RUN.

Generates:
- RUN/Assets.xcassets/Contents.json
- RUN/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png (opaque RGB, no alpha)
- RUN/Assets.xcassets/AppIcon.appiconset/Contents.json
- RUN/Assets.xcassets/AccentColor.colorset/Contents.json
- RUN/Assets.xcassets/LaunchBackground.colorset/Contents.json
"""

from __future__ import annotations

import json
import math
import struct
import zlib
from pathlib import Path


def clamp(v: float, lo: float = 0.0, hi: float = 1.0) -> float:
    return lo if v < lo else (hi if v > hi else v)


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    t = clamp((x - edge0) / (edge1 - edge0))
    return t * t * (3.0 - 2.0 * t)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def lerp_rgb(
    c1: tuple[float, float, float],
    c2: tuple[float, float, float],
    t: float,
) -> tuple[float, float, float]:
    t = clamp(t)
    return (lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t))


def blend(
    bg: tuple[float, float, float],
    fg: tuple[float, float, float],
    alpha: float,
) -> tuple[float, float, float]:
    a = clamp(alpha)
    return (
        bg[0] * (1.0 - a) + fg[0] * a,
        bg[1] * (1.0 - a) + fg[1] * a,
        bg[2] * (1.0 - a) + fg[2] * a,
    )


def dist_point_to_segment(
    px: float,
    py: float,
    ax: float,
    ay: float,
    bx: float,
    by: float,
) -> tuple[float, float]:
    dx = bx - ax
    dy = by - ay
    len_sq = dx * dx + dy * dy
    if len_sq <= 1e-12:
        return math.hypot(px - ax, py - ay), 0.0
    t = clamp(((px - ax) * dx + (py - ay) * dy) / len_sq)
    cx = ax + t * dx
    cy = ay + t * dy
    return math.hypot(px - cx, py - cy), t


def sd_polyline(
    px: float,
    py: float,
    points: list[tuple[float, float]],
) -> tuple[float, float]:
    best_d = 1e9
    best_t = 0.0
    seg_count = len(points) - 1
    for idx in range(seg_count):
        ax, ay = points[idx]
        bx, by = points[idx + 1]
        d, local_t = dist_point_to_segment(px, py, ax, ay, bx, by)
        if d < best_d:
            best_d = d
            best_t = (idx + local_t) / seg_count
    return best_d, best_t


def write_png_rgb(path: Path, width: int, height: int, rgb_bytes: bytes) -> None:
    stride = width * 3
    raw = bytearray((stride + 1) * height)
    for y in range(height):
        row_start = y * (stride + 1)
        raw[row_start] = 0  # filter type 0 (None)
        src_start = y * stride
        raw[row_start + 1 : row_start + 1 + stride] = rgb_bytes[
            src_start : src_start + stride
        ]

    compressed = zlib.compress(bytes(raw), level=6)

    def chunk(tag: bytes, payload: bytes) -> bytes:
        crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # RGB, no alpha
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", ihdr)
    png += chunk(b"IDAT", compressed)
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def render_icon(size: int = 1024) -> bytes:
    """Render an original geometric route-vector icon in Midnight Slate, Electric Teal, and Emerald."""
    bg_center = (11.0, 19.0, 43.0)   # #0B132B
    bg_edge = (22.0, 36.0, 71.0)     # #162447
    contour_col = (13.0, 148.0, 136.0)  # #0D9488
    teal = (0.0, 229.0, 255.0)       # #00E5FF
    emerald = (16.0, 185.0, 129.0)   # #10B981
    sky_white = (225.0, 252.0, 255.0)

    # Normalized [0, 1] coordinates (origin top-left)
    # Primary forward-leaning route chevron ribbon
    ribbon_main = [
        (0.21, 0.77),
        (0.41, 0.43),
        (0.56, 0.56),
        (0.76, 0.25),
    ]
    # Secondary parallel pace vector echo
    ribbon_echo = [
        (0.24, 0.58),
        (0.39, 0.31),
        (0.54, 0.43),
    ]
    beacon = (0.76, 0.25)

    aa = 1.5 / size
    out = bytearray(size * size * 3)
    idx = 0

    for y in range(size):
        ny = (y + 0.5) / size
        for x in range(size):
            nx = (x + 0.5) / size

            # Radial Midnight Slate gradient slightly offset toward upper-right apex
            rad = math.hypot(nx - 0.58, ny - 0.42) / 0.85
            col = lerp_rgb(bg_center, bg_edge, clamp(rad * 1.15))

            # Concentric elevation contour rings centered around the waypoint apex
            cdist = math.hypot(nx - 0.76, ny - 0.25)
            for ring_r in (0.22, 0.36, 0.50, 0.64, 0.78):
                ring_delta = abs(cdist - ring_r)
                if ring_delta < 0.006:
                    ring_alpha = 0.20 * (1.0 - smoothstep(0.001, 0.006, ring_delta))
                    col = blend(col, contour_col, ring_alpha)

            # Soft radial glow around the trail & beacon
            d_main, t_main = sd_polyline(nx, ny, ribbon_main)
            if d_main < 0.14:
                glow_col = lerp_rgb(emerald, teal, t_main)
                glow_alpha = 0.22 * (1.0 - smoothstep(0.0, 0.14, d_main)) ** 1.7
                col = blend(col, glow_col, glow_alpha)

            # Secondary parallel chevron echo ribbon
            d_echo, t_echo = sd_polyline(nx, ny, ribbon_echo)
            half_echo = 0.030
            if d_echo < half_echo + aa:
                echo_alpha = 0.42 * (1.0 - smoothstep(half_echo - aa, half_echo + aa, d_echo))
                echo_col = lerp_rgb((13.0, 148.0, 136.0), teal, t_echo)
                col = blend(col, echo_col, echo_alpha)

            # Primary geometric route ribbon (Emerald -> Electric Teal)
            half_main = 0.056
            if d_main < half_main + aa:
                main_alpha = 1.0 - smoothstep(half_main - aa, half_main + aa, d_main)
                ribbon_col = lerp_rgb(emerald, teal, t_main)
                # Subtle core highlight ridge
                ridge = 1.0 - smoothstep(0.0, half_main * 0.48, d_main)
                ribbon_col = blend(ribbon_col, sky_white, 0.18 * ridge)
                col = blend(col, ribbon_col, main_alpha)

            # Luminous waypoint beacon at apex
            b_dist = math.hypot(nx - beacon[0], ny - beacon[1])
            if b_dist < 0.14:
                b_glow = 0.45 * (1.0 - smoothstep(0.04, 0.14, b_dist)) ** 2
                col = blend(col, teal, b_glow)
            if b_dist < 0.072 + aa:
                outer_a = 1.0 - smoothstep(0.072 - aa, 0.072 + aa, b_dist)
                col = blend(col, teal, outer_a)
            if b_dist < 0.038 + aa:
                core_a = 1.0 - smoothstep(0.038 - aa, 0.038 + aa, b_dist)
                col = blend(col, sky_white, core_a)

            out[idx] = int(clamp(col[0], 0.0, 255.0) + 0.5)
            out[idx + 1] = int(clamp(col[1], 0.0, 255.0) + 0.5)
            out[idx + 2] = int(clamp(col[2], 0.0, 255.0) + 0.5)
            idx += 3

    return bytes(out)


def write_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    assets = root / "RUN" / "Assets.xcassets"
    appicon_dir = assets / "AppIcon.appiconset"
    accent_dir = assets / "AccentColor.colorset"
    launch_dir = assets / "LaunchBackground.colorset"

    appicon_dir.mkdir(parents=True, exist_ok=True)
    accent_dir.mkdir(parents=True, exist_ok=True)
    launch_dir.mkdir(parents=True, exist_ok=True)

    write_json(assets / "Contents.json", {"info": {"author": "xcode", "version": 1}})

    write_json(
        appicon_dir / "Contents.json",
        {
            "images": [
                {
                    "filename": "AppIcon-1024.png",
                    "idiom": "universal",
                    "platform": "ios",
                    "size": "1024x1024",
                }
            ],
            "info": {"author": "xcode", "version": 1},
        },
    )

    write_json(
        accent_dir / "Contents.json",
        {
            "colors": [
                {
                    "color": {
                        "color-space": "srgb",
                        "components": {
                            "alpha": "1.000",
                            "blue": "0.820",
                            "green": "0.761",
                            "red": "0.000",
                        },
                    },
                    "idiom": "universal",
                },
                {
                    "appearances": [
                        {"appearance": "luminosity", "value": "dark"}
                    ],
                    "color": {
                        "color-space": "srgb",
                        "components": {
                            "alpha": "1.000",
                            "blue": "1.000",
                            "green": "0.898",
                            "red": "0.000",
                        },
                    },
                    "idiom": "universal",
                },
            ],
            "info": {"author": "xcode", "version": 1},
        },
    )

    write_json(
        launch_dir / "Contents.json",
        {
            "colors": [
                {
                    "color": {
                        "color-space": "srgb",
                        "components": {
                            "alpha": "1.000",
                            "blue": "0.169",
                            "green": "0.075",
                            "red": "0.043",
                        },
                    },
                    "idiom": "universal",
                }
            ],
            "info": {"author": "xcode", "version": 1},
        },
    )

    rgb = render_icon(1024)
    write_png_rgb(appicon_dir / "AppIcon-1024.png", 1024, 1024, rgb)
    print(f"Generated {(appicon_dir / 'AppIcon-1024.png')} ({len(rgb)} RGB bytes)")


if __name__ == "__main__":
    main()
