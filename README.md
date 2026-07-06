# SPC Pocket Player

An [openFPGA](https://www.analogue.co/developer) core for the **Analogue Pocket**
that plays SNES/Super Famicom **.spc** music files on a real hardware
implementation of the S-SMP (SPC700) + S-DSP audio subsystem, extracted from
the [MiSTer SNES core](https://github.com/MiSTer-devel/SNES_MiSTer) by srg320
(via [agg23's openFPGA port](https://github.com/agg23/openfpga-SNES)).

Nothing is emulated at the software level: the SPC700 CPU executes the music
driver from the .spc dump and the S-DSP renders the voices at the original
32 kHz, clocked at the authentic 21.47727 MHz master clock.

## Architecture

```
.spc file (SD card)
   │  APF bridge (data slot 0 @ 0x10000000)
   ▼
data_loader (CDC 74.25 MHz → 21.47727 MHz, 16-bit LE words)
   ▼
spc_apu.vhd ── loader FSM routes the file:
   ├─ header 0x25-0x2B ───────► SPC700 registers (PC/A/X/Y/PSW/SP) via IO port
   ├─ 64KB ARAM image ────────► dual-port BRAM (also captures $F0-$FF page)
   ├─ DSP regs @0x10100 ──────► DSP register file via IO port (0x100-0x17F)
   ├─ extra RAM @0x101C0 ─────► ARAM $FFC0-$FFFF
   └─ after load: replays $F0-$FF page → IO 0x2F0-0x2FE
      (SMP control/timers/DSP address latch), then releases APU reset
   ▼
SMP (SPC700) ◄──► DSP ◄──► ARAM BRAM ──► AUDIO_L/R @32kHz ──► sound_i2s (48kHz I2S)
```

Video output is 512×240 at 60.09 Hz (SNES-like timing, 10.738635 MHz dot
clock): track counter, ID666 song/game title, and stereo VU meters.

## Albums (.spcpak)

The data slot is `deferload`: the core pulls one 0x10200-byte song at a time
with `target_dataslot_read`, so a single file can hold a whole soundtrack.

```sh
python3 tools/make_spcpak.py ~/spc/chrono-trigger/ -o "Chrono Trigger.spcpak"
```

A plain `.spc` is just a 1-song pack — both load the same way.

**Library packs**: pack your entire collection into one indexed file (one
album per folder) and never touch the file browser again:

```sh
./tools/pack_all.sh ~/spc /media/sd/Assets/spc/common --library
```

L1/R1 jump between albums. Packs made by older tool versions (no index)
still play as a single album.

**Controls**: dpad right = next track, dpad left = previous track,
A = restart track, Y = shuffle on/off ("S" indicator on screen; next/auto
picks a random other track while enabled), L1/R1 = previous/next album
(indexed packs).

**Display**: track number, shuffle indicator, elapsed/total time (MM:SS),
song + game title, 8 per-voice envelope bars (one colored column per DSP
voice), and stereo VU strips.

**Fade-out**: tagged songs fade over their final 2 seconds before
advancing.

**Auto-advance**: the pack tool reads each song's ID666 length+fade tag
(or `--default-length`, 180s, when untagged; 0 = loop forever) and stamps it
into the entry; the core moves to the next track when the time is up. Plain
`.spc` files loaded directly loop forever.

**Status indicators**: a full border is shown only before the first song
plays (red = waiting for a file, orange = loading, magenta = read failed
after ~10 automatic retries). After that, a small square in the top-right
corner shows the same colors whenever playback is stopped; track changes
keep the normal UI on screen.

**File changes**: after picking a new file the core waits ~0.5s before
reading it (APF needs time to swap files), and the command channel has a
watchdog so a misbehaving transfer can never require a core reboot.

**Echo-buffer hygiene**: many SPC dumps carry garbage in the echo buffer
region, audible as a noise burst with an echo tail at song start. The
loader zeroes the echo region on every load (only when the song has echo
writes enabled, so repurposed RAM is never touched).

## Building

Requires Quartus Prime (Lite) with Cyclone V support.

```sh
./build.sh          # compile + bit-reverse + assemble SD tree in out/
```

Copy the contents of `out/` onto the Pocket's SD card root, then put your
`.spc`/`.spcpak` files in `/Assets/spc/common/`. Launch the "SPC Player"
core and pick a file.

## Simulation

The APU + loader are fully simulatable with GHDL (no license needed):

```sh
python3 tools/make_test_spc.py sim/test_tone.spc   # deterministic 1kHz tone
python3 tools/make_arp_spc.py  sim/test_arp.spc    # timers+ADSR+echo test
./sim/run_sim.sh test_tone.spc 100                 # renders 100ms of audio
python3 tools/raw_to_wav.py sim/work/audio_out.raw # convert + analyze
```

The testbench streams the real .spc file through the same loader interface
the Pocket uses and dumps every 32 kHz sample pair to `sim/work/audio_out.raw`.

## Current limitations

**Changing files mid-session does not work — pack a library instead.**
This core streams songs on demand from a `deferload` data slot using APF's
`target_dataslot_read`. That works perfectly for the file selected at core
launch, but the Pocket firmware does not properly support *replacing* the
file afterwards: after picking a new file from the menu, the slot's size is
updated but every subsequent read silently never completes (tested across
firmware versions). The documented remedies don't work either — the
`getfile` (0x0190) and `openfile` (0x0192) target commands complete with
success codes but never actually deliver the filename struct (verified at
two different buffer addresses; no shipping core uses these commands, and
the PC Engine CD core — the other user of deferload — simply displays an
error on file changes).

The practical answers, in order of preference:

1. **Pack your whole collection into one indexed library pack**
   (`pack_all.sh <root> --library`) and never touch the file browser again:
   L1/R1 jump between albums, shuffle and auto-advance work across
   everything.
2. To switch to a different file, **quit and relaunch the core** (a few
   seconds) — the launch-time load path is fully reliable.

Other limitations:

- Extended ID666 (xid6) tags are ignored; play lengths come from the
  standard header tags (or `--default-length` at pack time).
- Audio is sample-and-held from the DSP's native 32kHz to the Pocket's
  48kHz I2S (same approach as the SNES core).
- The DSP register snapshot restores what the .spc format captures; voices
  keyed on at dump time restart from their sample beginnings (a format
  limitation shared by all SPC players).
- Packs created by tool versions before the index/length features still
  play, as a single album without auto-advance.

## Licenses

- SNES APU RTL (`src/fpga/core/spc/`): GPL-2.0+ (srg320, MiSTer project)
- `data_loader.sv`, `sound_i2s.sv`, `sync_fifo.sv`: MIT (Adam Gastineau)
- APF framework files (`src/fpga/apf/`): Analogue core template
- Everything else in this repo: GPL-3.0
