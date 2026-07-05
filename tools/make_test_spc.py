#!/usr/bin/env python3
"""Generate a synthetic .spc test file that plays a steady 1 kHz square tone.

The SPC700 program itself performs the key-on (writing DSP KON via $F2/$F3),
so this file exercises the CPU, the SMP register page, and the DSP voice
pipeline - a deterministic end-to-end test for the FPGA APU.

Layout of a v0.30 SPC file:
  0x00-0x20  "SNES-SPC700 Sound File Data v0.30"
  0x21-0x22  0x1A 0x1A
  0x23       0x1A = ID666 tag present, 0x1B = absent
  0x24       minor version (30)
  0x25-0x26  PC (little endian)
  0x27..0x2B A, X, Y, PSW, SP
  0x2E..     ID666 text tags
  0x100      64 KB ARAM image
  0x10100    128 bytes DSP registers
  0x10180    64 bytes unused
  0x101C0    64 bytes extra RAM (ARAM $FFC0-$FFFF hidden under IPL ROM)
"""
import struct
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "test_tone.spc"

aram = bytearray(0x10000)

# --- BRR sample: one period of a 32-sample square wave, looping forever ---
# Two 9-byte BRR blocks; range=11, filter=0 -> nibble 7 -> +14336, nibble 9(-7) -> -14336
SAMPLE_ADDR = 0x0300
def brr_block(nibbles, loop, end):
    hdr = (11 << 4) | (0 << 2) | (loop << 1) | end
    body = bytearray()
    for i in range(0, 16, 2):
        body.append(((nibbles[i] & 0xF) << 4) | (nibbles[i + 1] & 0xF))
    return bytes([hdr]) + bytes(body)

pos_half = [7] * 16          # +7 << 11 = +14336
neg_half = [0x9] * 16        # -7 << 11 = -14336 (two's complement nibble)
aram[SAMPLE_ADDR:SAMPLE_ADDR + 9] = brr_block(pos_half, loop=1, end=0)
aram[SAMPLE_ADDR + 9:SAMPLE_ADDR + 18] = brr_block(neg_half, loop=1, end=1)

# --- Sample directory at page 2 (DIR=0x02 -> 0x0200), entry 0 ---
DIR_ADDR = 0x0200
aram[DIR_ADDR:DIR_ADDR + 4] = struct.pack("<HH", SAMPLE_ADDR, SAMPLE_ADDR)

# --- SPC700 program at 0x0400: key on voice 0, then spin ---
PC = 0x0400
prog = bytes([
    0x8F, 0x6C, 0xF2,   # MOV $F2, #$6C   ; DSP addr = FLG
    0x8F, 0x20, 0xF3,   # MOV $F3, #$20   ; echo off, mute off, noise 0
    0x8F, 0x4C, 0xF2,   # MOV $F2, #$4C   ; DSP addr = KON
    0x8F, 0x01, 0xF3,   # MOV $F3, #$01   ; key on voice 0
    0x2F, 0xFE,         # BRA *           ; loop forever
])
aram[PC:PC + len(prog)] = prog

# --- SMP register page snapshot ($F0-$FF within ARAM image) ---
aram[0xF0] = 0x0A   # TEST: timers enabled, RAM write enabled (normal value)
aram[0xF1] = 0x80   # CONTROL: IPL ROM mapped, timers stopped
aram[0xF2] = 0x4C   # DSPADDR last value

# --- DSP registers ---
dsp = bytearray(128)
dsp[0x00] = 0x7F    # V0 VOLL
dsp[0x01] = 0x7F    # V0 VOLR
dsp[0x02] = 0x00    # V0 PITCH L
dsp[0x03] = 0x10    # V0 PITCH H = 0x1000 -> 1.0x -> 32000/32 = 1 kHz
dsp[0x04] = 0x00    # V0 SRCN = 0
dsp[0x05] = 0x00    # V0 ADSR1: ADSR disabled -> GAIN mode
dsp[0x07] = 0x7F    # V0 GAIN: direct, max
dsp[0x0C] = 0x7F    # MVOL L
dsp[0x1C] = 0x7F    # MVOL R
dsp[0x2C] = 0x00    # EVOL L
dsp[0x3C] = 0x00    # EVOL R
dsp[0x4C] = 0x00    # KON  (program does the key-on itself)
dsp[0x5C] = 0x00    # KOF
dsp[0x5D] = 0x02    # DIR page = 0x0200
dsp[0x6C] = 0x20    # FLG: reset off, mute off, echo write disabled
dsp[0x6D] = 0xF8    # ESA (echo region, unused)
dsp[0x7D] = 0x00    # EDL

# --- Assemble file ---
hdr = bytearray(0x100)
hdr[0x00:0x21] = b"SNES-SPC700 Sound File Data v0.30"
hdr[0x21] = 0x1A
hdr[0x22] = 0x1A
hdr[0x23] = 0x1A            # ID666 present
hdr[0x24] = 30              # version
struct.pack_into("<H", hdr, 0x25, PC)
hdr[0x27] = 0x00            # A
hdr[0x28] = 0x00            # X
hdr[0x29] = 0x00            # Y
hdr[0x2A] = 0x02            # PSW (Z set, arbitrary)
hdr[0x2B] = 0xEF            # SP
hdr[0x2E:0x2E + 20] = b"Test Tone 1kHz".ljust(20, b"\x00")   # song title
hdr[0x4E:0x4E + 20] = b"spc-pocket-player".ljust(20, b"\x00")  # game title

out = bytes(hdr) + bytes(aram) + bytes(dsp) + bytes(64) + bytes(aram[0xFFC0:0x10000])
assert len(out) == 0x10200, hex(len(out))
open(OUT, "wb").write(out)
print(f"wrote {OUT}: {len(out):#x} bytes, PC={PC:#06x}, tone=1000 Hz square")
