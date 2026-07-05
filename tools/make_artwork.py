#!/usr/bin/env python3
"""Generate Pocket artwork: core icon.bin (36x36) and platform image (521x165).

Format (deduced from shipped cores): 2 bytes/pixel, brightness in byte 0,
byte 1 zero; the file stores the image rotated 90 degrees counter-clockwise
(file pixel (row r, col c) = original pixel (x = W-1-r, y = c)).
"""
import re
import sys
from pathlib import Path

FONT_H = Path(__file__).parent / "font8x8_basic.h"
glyphs = re.findall(
    r"\{\s*((?:0x[0-9A-Fa-f]{2}\s*,\s*){7}0x[0-9A-Fa-f]{2})\s*\}", FONT_H.read_text())
FONT = {chr(i): [int(x, 16) for x in re.split(r"\s*,\s*", glyphs[i])] for i in range(128)}


def draw_text(img, W, H, text, x0, y0, scale, val=255):
    for ci, ch in enumerate(text):
        g = FONT.get(ch, FONT[" "])
        for ry in range(8):
            for rx in range(8):
                if g[ry] >> rx & 1:
                    for sy in range(scale):
                        for sx in range(scale):
                            x = x0 + (ci * 8 + rx) * scale + sx
                            y = y0 + ry * scale + sy
                            if 0 <= x < W and 0 <= y < H:
                                img[y][x] = val


def draw_note(img, W, H, x0, y0, scale, val=255):
    """Eighth note: head ellipse, stem, flag. Design box is 16x24 units."""
    for y in range(24 * scale):
        for x in range(16 * scale):
            u, v = x / scale, y / scale
            on = False
            # head: ellipse centered (5,20), rx 4.5, ry 3.2
            if ((u - 5) / 4.5) ** 2 + ((v - 20) / 3.2) ** 2 <= 1:
                on = True
            # stem: x 8.6-10, y 2-20
            if 8.6 <= u <= 10 and 2 <= v <= 20:
                on = True
            # flag: curve from stem top
            if 2 <= v <= 9 and 10 <= u <= 10 + 4.5 * (1 - abs(v - 5.5) / 3.5):
                on = True
            if on:
                px, py = x0 + x, y0 + y
                if 0 <= px < W and 0 <= py < H:
                    img[py][px] = val


def emit(img, W, H, path):
    out = bytearray()
    for r in range(W):
        for c in range(H):
            out.append(img[c][W - 1 - r])
            out.append(0)
    Path(path).write_bytes(out)
    print(f"wrote {path} ({len(out)} bytes)")


# ---- icon 36x36: eighth note ----
W, H = 36, 36
icon = [[0] * W for _ in range(H)]
draw_note(icon, W, H, 4, 4, 1, 255)
draw_text(icon, W, H, "SPC", 4, 26, 1, 200)
emit(icon, W, H, "pkg/Cores/cbravoa.SPCPlayer/icon.bin")

# ---- platform image 521x165 ----
W, H = 521, 165
plat = [[0] * W for _ in range(H)]
draw_note(plat, W, H, 30, 22, 5, 255)
draw_text(plat, W, H, "SPC", 130, 30, 8, 255)
draw_text(plat, W, H, "SUPER NINTENDO MUSIC", 130, 105, 2, 160)
emit(plat, W, H, "pkg/Platforms/_images/spc.bin")
