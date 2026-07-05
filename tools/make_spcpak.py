#!/usr/bin/env python3
"""Pack a folder of .spc files into a single .spcpak album for the Pocket core.

Format: N entries, each exactly 0x10200 bytes (a normalized SPC image:
0x100 header + 64KB ARAM + 128 DSP regs + 64 unused + 64 extra RAM).
Files with extended ID666 data beyond 0x10200 are truncated (the extra
metadata is not needed for playback); short files are zero-padded.
A single plain .spc file is itself a valid 1-song pack.

Usage: make_spcpak.py <folder-or-files...> [-o album.spcpak]
"""
import argparse
import sys
from pathlib import Path

ENTRY = 0x10200

ap = argparse.ArgumentParser()
ap.add_argument("inputs", nargs="+", help=".spc files and/or folders")
ap.add_argument("-o", "--output", default=None)
args = ap.parse_args()

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
    print(f"  [{len(blob)//ENTRY + 1:3d}] {f.name:40s} {title}")
    blob += entry

open(out, "wb").write(blob)
print(f"wrote {out}: {len(blob)//ENTRY} songs, {len(blob)} bytes")
