#!/usr/bin/env python3
"""Generate a harder synthetic .spc: timer-driven arpeggio, 2 voices with
ADSR, echo enabled. Exercises SMP timers, envelope hardware, echo ARAM
traffic and runtime DSP register writes - the paths a real game SPC uses.

Expected audible result: a two-voice arpeggio stepping at ~64 Hz between
pitch-high values 0x10/0x0C/0x08/0x0E (1000/750/500/875 Hz fundamentals for
the 32-sample loop), with an echo tail.
"""
import struct
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "test_arp.spc"

aram = bytearray(0x10000)

# --- BRR: same 32-sample square loop as the tone test ---
SAMPLE_ADDR = 0x0300
def brr_block(nibbles, loop, end):
    hdr = (11 << 4) | (0 << 2) | (loop << 1) | end
    body = bytearray()
    for i in range(0, 16, 2):
        body.append(((nibbles[i] & 0xF) << 4) | (nibbles[i + 1] & 0xF))
    return bytes([hdr]) + bytes(body)

aram[SAMPLE_ADDR:SAMPLE_ADDR + 9] = brr_block([7] * 16, loop=1, end=0)
aram[SAMPLE_ADDR + 9:SAMPLE_ADDR + 18] = brr_block([0x9] * 16, loop=1, end=1)

DIR_ADDR = 0x0200
aram[DIR_ADDR:DIR_ADDR + 4] = struct.pack("<HH", SAMPLE_ADDR, SAMPLE_ADDR)

# --- pitch-high table ---
TABLE = 0x0500
aram[TABLE:TABLE + 4] = bytes([0x10, 0x0C, 0x08, 0x0E])

# --- SPC700 program ---
PC = 0x0400
prog = bytes([
    0x8F, 0x4C, 0xF2,   # MOV $F2,#$4C     ; DSP addr = KON
    0x8F, 0x03, 0xF3,   # MOV $F3,#$03     ; key on voices 0+1
    0x8F, 0x7D, 0xFA,   # MOV $FA,#$7D     ; timer0 divider 125 -> 64 Hz
    0x8F, 0x81, 0xF1,   # MOV $F1,#$81     ; IPL on, enable timer0
    # loop:
    0xE4, 0xFD,         # MOV A,$FD        ; read timer0 out (self-clearing)
    0xF0, 0xFC,         # BEQ loop
    0xE4, 0x20,         # MOV A,$20        ; arpeggio index
    0xBC,               # INC A
    0x28, 0x03,         # AND A,#$03
    0xC4, 0x20,         # MOV $20,A
    0x5D,               # MOV X,A
    0xF5, 0x00, 0x05,   # MOV A,$0500+X    ; fetch pitch-high
    0x8F, 0x03, 0xF2,   # MOV $F2,#$03     ; DSP addr = V0 pitch H
    0xC4, 0xF3,         # MOV $F3,A
    0x8F, 0x13, 0xF2,   # MOV $F2,#$13     ; DSP addr = V1 pitch H
    0xC4, 0xF3,         # MOV $F3,A
    0x2F, 0xE5,         # BRA loop
])
aram[PC:PC + len(prog)] = prog
aram[0x20] = 0          # arpeggio index

# --- SMP register page snapshot ---
aram[0xF0] = 0x0A       # TEST: normal
aram[0xF1] = 0x80       # CONTROL: IPL on, timers off (program enables t0)
aram[0xF2] = 0x4C

# --- DSP registers ---
dsp = bytearray(128)
# voice 0
dsp[0x00] = 0x60; dsp[0x01] = 0x60          # VOL
dsp[0x02] = 0x00; dsp[0x03] = 0x10          # pitch 0x1000
dsp[0x04] = 0x00                            # SRCN
dsp[0x05] = 0x8F; dsp[0x06] = 0xE0          # ADSR: AR=15, DR=0, SL=7, SR=0
# voice 1 (a fifth up)
dsp[0x10] = 0x40; dsp[0x11] = 0x40
dsp[0x12] = 0x00; dsp[0x13] = 0x18          # pitch 0x1800
dsp[0x14] = 0x00
dsp[0x15] = 0x8F; dsp[0x16] = 0xE0
# globals
dsp[0x0C] = 0x50; dsp[0x1C] = 0x50          # MVOL
dsp[0x2C] = 0x30; dsp[0x3C] = 0x30          # EVOL
dsp[0x2D] = 0x00                            # PMON off
dsp[0x3D] = 0x00                            # NON off
dsp[0x4D] = 0x03                            # EON: echo voices 0+1
dsp[0x5D] = 0x02                            # DIR
dsp[0x6C] = 0x00                            # FLG: echo write ENABLED
dsp[0x6D] = 0xC0                            # ESA = 0xC000
dsp[0x7D] = 0x02                            # EDL = 2 (32ms)
dsp[0x0D] = 0x40                            # EFB
dsp[0x0F] = 0x7F                            # FIR C0 (pass-through)

hdr = bytearray(0x100)
hdr[0x00:0x21] = b"SNES-SPC700 Sound File Data v0.30"
hdr[0x21] = 0x1A
hdr[0x22] = 0x1A
hdr[0x23] = 0x1A
hdr[0x24] = 30
struct.pack_into("<H", hdr, 0x25, PC)
hdr[0x27] = 0x00
hdr[0x28] = 0x00
hdr[0x29] = 0x00
hdr[0x2A] = 0x02
hdr[0x2B] = 0xEF
hdr[0x2E:0x2E + 20] = b"Arp+Echo Test".ljust(20, b"\x00")
hdr[0x4E:0x4E + 20] = b"spc-pocket-player".ljust(20, b"\x00")

out = bytes(hdr) + bytes(aram) + bytes(dsp) + bytes(64) + bytes(aram[0xFFC0:0x10000])
assert len(out) == 0x10200
open(OUT, "wb").write(out)
print(f"wrote {OUT}: arpeggio @64Hz, 2 voices, ADSR, echo on")
