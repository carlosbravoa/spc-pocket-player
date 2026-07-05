#!/usr/bin/env python3
"""Pack a folder of .spc files into a single .spcpak album for the Pocket core.

Format: N entries, each exactly 0x10200 bytes (a normalized SPC image:
0x100 header + 64KB ARAM + 128 DSP regs + 64 unused + 64 extra RAM).
Files with extended ID666 data beyond 0x10200 are truncated (the extra
metadata is not needed for playback); short files are zero-padded.
A single plain .spc file is itself a valid 1-song pack.

Auto-advance: each entry's play length in seconds (ID666 length + fade,
or --default-length when untagged) is stamped as a little-endian u16 at
entry offset 0x10180 with magic "PL" at 0x10182 (a region the SPC format
leaves unused). The core advances to the next track when time is up.

Usage: make_spcpak.py <folder-or-files...> [-o album.spcpak]
"""
import argparse
import struct
import sys
from pathlib import Path

ENTRY = 0x10200

ap = argparse.ArgumentParser()
ap.add_argument("inputs", nargs="+", help=".spc files and/or folders")
ap.add_argument("-o", "--output", default=None)
ap.add_argument("--default-length", type=int, default=180, metavar="SECONDS",
                help="play length for untagged songs (0 = loop forever, default 180)")
args = ap.parse_args()


def id666_length(d):
    """Return play length in seconds (length + fade) or None if untagged.
    Handles both text and binary ID666 variants."""
    if len(d) < 0x100 or d[0x23] != 0x1A:
        return None
    sec_f = d[0xA9:0xAC]
    fade_f = d[0xAC:0xB1]
    text_chars = set(b"0123456789 \x00")
    if set(sec_f) <= text_chars and set(fade_f) <= text_chars:
        # text variant: ASCII digits
        sec_s = bytes(c for c in sec_f if c in b"0123456789")
        fade_s = bytes(c for c in fade_f if c in b"0123456789")
        sec = int(sec_s) if sec_s else 0
        fade_ms = int(fade_s) if fade_s else 0
    else:
        # binary variant: 3-byte LE seconds, 4-byte LE fade in ms
        sec = int.from_bytes(sec_f, "little")
        fade_ms = int.from_bytes(d[0xAC:0xB0], "little")
        if sec > 86400 or fade_ms > 600000:   # implausible -> treat as untagged
            return None
    if sec == 0:
        return None
    return min(0xFFFE, sec + (fade_ms + 999) // 1000)

files = []
for inp in args.inputs:
    p = Path(inp)
    if p.is_dir():
        files += sorted(p.glob("*.spc")) + sorted(p.glob("*.SPC"))
    else:
        files.append(p)

if not files:
    sys.exit("no .spc files found")

if args.output:
    out = Path(args.output)
elif Path(args.inputs[0]).is_dir():
    out = Path(Path(args.inputs[0]).resolve().name + ".spcpak")
else:
    out = Path("album.spcpak")

blob = bytearray()
for f in files:
    d = open(f, "rb").read()
    if d[:27] != b"SNES-SPC700 Sound File Data":
        print(f"  skipping {f.name}: not an SPC file")
        continue
    if len(d) < 0x10180:
        print(f"  skipping {f.name}: truncated file ({len(d):#x} bytes)")
        continue
    entry = bytearray(d[:ENTRY])
    entry += bytes(ENTRY - len(entry))
    title = entry[0x2E:0x4E].split(b"\x00")[0].decode("latin1", "replace")
    length = id666_length(d)
    if length is None:
        length = args.default_length
    if length > 0:
        struct.pack_into("<HH", entry, 0x10180, length, 0x4C50)   # "PL"
        length_txt = f"{length//60}:{length%60:02d}"
    else:
        struct.pack_into("<HH", entry, 0x10180, 0, 0)
        length_txt = "loop"
    print(f"  [{len(blob)//ENTRY + 1:3d}] {f.name:40s} {length_txt:>6s}  {title}")
    blob += entry

open(out, "wb").write(blob)
print(f"wrote {out}: {len(blob)//ENTRY} songs, {len(blob)} bytes")
