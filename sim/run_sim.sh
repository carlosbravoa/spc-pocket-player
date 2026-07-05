#!/bin/bash
# Analyze + elaborate + run the spc_apu testbench under GHDL.
# Usage: ./run_sim.sh [spc_file] [run_ms]
set -e
cd "$(dirname "$0")"

GHDL=${GHDL:-$HOME/tools/ghdl-mcode-6.0.0-ubuntu24.04-x86_64/bin/ghdl}
SIMLIB=$HOME/altera_lite/25.1std/quartus/eda/sim_lib
RTL=$(cd ../src/fpga/core/spc && pwd)
FLAGS="--std=08 -fsynopsys -fexplicit"
SPC=${1:-test_tone.spc}
RUN_MS=${2:-100}
SPC2=${3:-}
RUN2_MS=${4:-60}

mkdir -p work
cd work

if [ ! -f altera_mf-obj08.cf ]; then
    $GHDL -a $FLAGS --work=altera_mf "$SIMLIB/altera_mf_components.vhd" "$SIMLIB/altera_mf.vhd"
fi

# bram.vhd reordered for analysis order + 'entity' keyword fixes
python3 - <<'EOF'
import re
src = open('../../src/fpga/core/spc/bram.vhd').read()
src = src.replace('mem_init_file : string := " "', 'mem_init_file : string := "UNUSED"')
src = src.replace('spram_sz : work.spram_sz', 'spram_sz : entity work.spram_sz')
src = src.replace('ram : work.dpram_dif', 'ram : entity work.dpram_dif')
lines = src.split('\n')
starts = [i for i, l in enumerate(lines) if l.strip() == 'LIBRARY ieee;']
starts.append(len(lines))
units = {}
for a, b in zip(starts, starts[1:]):
    chunk = '\n'.join(lines[a:b])
    m = re.search(r'(?im)^\s*entity\s+(\w+)\s+is', chunk)
    units[m.group(1).lower()] = chunk
order = ['spram_sz', 'spram', 'dpram_dif', 'dpram', 'dpram_difclk']
open('bram_sim.vhd', 'w').write('\n\n'.join(units[n] for n in order))
EOF

$GHDL -a $FLAGS bram_sim.vhd \
    $RTL/CEGen.vhd \
    $RTL/SPC700/SPC700_pkg.vhd $RTL/SPC700/AddSub.vhd $RTL/SPC700/BCDAdj.vhd \
    $RTL/SPC700/MCode.vhd $RTL/SPC700/AddrGen.vhd $RTL/SPC700/MulDiv.vhd \
    $RTL/SPC700/ALU.vhd $RTL/SPC700/SPC700.vhd \
    $RTL/DSP_PKG.vhd $RTL/SMP.vhd $RTL/DSP.vhd \
    $RTL/spc_apu.vhd \
    ../spc_apu_tb.vhd

$GHDL -e $FLAGS spc_apu_tb

cp -f "../$SPC" ./ 2>/dev/null || true
GEN2=""
if [ -n "$SPC2" ]; then
    cp -f "../$SPC2" ./ 2>/dev/null || true
    GEN2="-gSPC_FILE2=$(basename "$SPC2") -gRUN2_MS=$RUN2_MS"
fi
echo "=== running: $SPC for ${RUN_MS}ms ${SPC2:+then $SPC2 for ${RUN2_MS}ms} ==="
$GHDL -r $FLAGS spc_apu_tb -gSPC_FILE="$(basename "$SPC")" -gRUN_MS="$RUN_MS" $GEN2 \
    --ieee-asserts=disable 2>&1 | grep -v "metavalue" | tail -40
echo "=== done: audio in sim/work/audio_out.raw ==="
