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

**Controls**: dpad right = next track, dpad left = previous track,
A = restart track, Y = shuffle on/off ("S" indicator on screen; next/auto
picks a random other track while enabled).

**Display**: track number, shuffle indicator, elapsed/total time (MM:SS),
song + game title, stereo VU meters.

**Fade-out**: tagged songs fade over their final 2 seconds before
advancing.

**Auto-advance**: the pack tool reads each song's ID666 length+fade tag
(or `--default-length`, 180s, when untagged; 0 = loop forever) and stamps it
into the entry; the core moves to the next track when the time is up. Plain
`.spc` files loaded directly loop forever.

**Status border** (shown only before the first song plays, or on a
persistent error): red = waiting for a file, orange = loading, magenta =
file read failed (the core retries automatically ~10 times first). Track
changes keep the normal UI on screen.

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

## Licenses

- SNES APU RTL (`src/fpga/core/spc/`): GPL-2.0+ (srg320, MiSTer project)
- `data_loader.sv`, `sound_i2s.sv`, `sync_fifo.sv`: MIT (Adam Gastineau)
- APF framework files (`src/fpga/apf/`): Analogue core template
- Everything else in this repo: GPL-3.0
