#!/usr/bin/env python3
"""Convert the simulator's raw s16le stereo 32kHz dump to WAV and print a
quick spectral summary (dominant frequency per 50ms window)."""
import struct
import sys
import wave

raw = sys.argv[1] if len(sys.argv) > 1 else "sim/work/audio_out.raw"
out = sys.argv[2] if len(sys.argv) > 2 else raw.rsplit(".", 1)[0] + ".wav"

data = open(raw, "rb").read()
n = len(data) // 4

with wave.open(out, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(32000)
    w.writeframes(data[: n * 4])
print(f"{out}: {n} samples ({n/32000:.3f}s)")

# dominant frequency per window via zero crossings + simple DFT peak
samples = struct.unpack(f"<{n*2}h", data[: n * 4])
L = samples[0::2]
win = 1600  # 50 ms
for i in range(0, n - win, win):
    seg = L[i : i + win]
    rms = (sum(v * v for v in seg) / win) ** 0.5
    # coarse DFT peak search 100..4000 Hz
    import math
    best_f, best_m = 0, 0.0
    for f in range(100, 4000, 25):
        re = sum(v * math.cos(2 * math.pi * f * k / 32000) for k, v in enumerate(seg))
        im = sum(v * math.sin(2 * math.pi * f * k / 32000) for k, v in enumerate(seg))
        m = re * re + im * im
        if m > best_m:
            best_m, best_f = m, f
    print(f"  {i/32000*1000:6.0f} ms: rms={rms:7.1f}  peak~{best_f} Hz")
