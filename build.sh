#!/bin/bash
# Full build: Quartus compile -> reversed RBF -> assembled SD-card tree in out/
set -e
cd "$(dirname "$0")"

QUARTUS=${QUARTUS:-$HOME/altera_lite/25.1std/quartus/bin/quartus_sh}

echo "=== Quartus compile ==="
(cd src/fpga && "$QUARTUS" --flow compile ap_core)

echo "=== Reversing RBF ==="
python3 tools/reverse_bits.py src/fpga/output_files/ap_core.rbf \
    pkg/Cores/cbravoa.SPCPlayer/bitstream.rbf_r

echo "=== Assembling SD tree in out/ ==="
rm -rf out
mkdir -p out
cp -r pkg/Cores pkg/Platforms pkg/Assets out/
# ship the test tunes as a sample album
python3 tools/make_test_spc.py /tmp/test_tone.spc
python3 tools/make_arp_spc.py /tmp/test_arp.spc
python3 tools/make_spcpak.py /tmp/test_tone.spc /tmp/test_arp.spc -o "out/Assets/spc/common/Test Album.spcpak"
rm -f /tmp/test_tone.spc /tmp/test_arp.spc

echo "=== Done. Copy the contents of out/ onto the Pocket SD card root. ==="
