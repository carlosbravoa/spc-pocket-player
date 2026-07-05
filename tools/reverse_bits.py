#!/usr/bin/env python3
"""Bit-reverse every byte of an RBF for the Analogue Pocket (.rbf_r)."""
import sys

table = bytes(int(f"{i:08b}"[::-1], 2) for i in range(256))
data = open(sys.argv[1], "rb").read()
open(sys.argv[2], "wb").write(data.translate(table))
print(f"{sys.argv[1]} -> {sys.argv[2]} ({len(data)} bytes)")
