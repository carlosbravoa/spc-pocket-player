# Mid-session file re-pick on a `deferload` data slot — SOLVED

**Status: SOLVED.** The cause was a single wrong bit in the slot's `data.json`
`parameters`. **Do not set bit 8 (`0x100`, "reload bitstream before core restart")
on a `deferload` slot you want to re-pick live.** With that bit set, the Pocket host
silently refuses to service `target_dataslot_read` after a menu re-pick (no ack, no
done). Remove it and mid-session re-pick works with plain `target_dataslot_read` —
exactly like the Amiga (floppy) and PC Engine CD (disc) cores.

## TL;DR fix

- Our slot had `"parameters": "0x109"` (bits 0 user-reloadable, 3 read-only, **8
  reload-bitstream**). Changing it to **`"0x09"`** (bits 0 + 3, matching the PCE-CD
  cue/bin slots) fixed it completely. No RTL change.
- Live-swap reference configs: Amiga floppy `parameters: 1`; PCE-CD cue/bin
  `0x09`/`0x08`. None set bit 8. Bit 8 was the one bit we had that they didn't.
- The re-pick handling itself is trivial: on `dataslot_update` (0x008A), re-read the
  new size from the data table and re-issue the same plain `target_dataslot_read`.
  **No `getfile`/`openfile`, no re-arm, no restart.** (A failed `openfile` — see §5 —
  actively corrupts the slot handle; we had added it as a "fix" and it was making
  things worse. Deleted.)

The original investigation notes are kept below for the record.

---

**Original status (now resolved):** Open / unsolved.

**Applies to:** Analogue Pocket openFPGA cores that use a `deferload` data slot and
`target_dataslot_read` to stream file contents on demand (as opposed to letting APF
push a whole file into the core at load time).

---

## 1. Summary

A core declares one `deferload` data slot and reads file contents on demand with the
`target_dataslot_read` (0x0180) target command. **This works perfectly for the file
selected when the core is launched.** However, if the user opens the core's menu and
**selects a different file for the same slot while the core is running**, every
subsequent `target_dataslot_read` on that slot **silently never completes** — the
command receives no `ack` and no `done`, indefinitely. The core's view of the slot
*size* updates correctly (so metadata like a track/entry count refreshes), but no data
can be read. Only relaunching the core restores the ability to read.

The two documented target commands intended to re-establish access after a file change
— `getfile` (0x0190) and `openfile` (0x0192) — do **not** resolve it in our testing
(details in §5). We currently believe mid-session re-pick is **unsupported by the
Pocket firmware** for this class of core, but we cannot confirm that from outside, and
we would like to be proven wrong.

---

## 2. Context / how the loading path works

- `data.json` declares a single slot: `deferload: true`, `required: true`, a large
  `size_maximum`, `address: 0x30000000`.
- At core launch the user is required to pick a file. APF writes the slot's **size**
  into the data table but (per `deferload`) does **not** stream the file.
- The core reads content with `target_dataslot_read`: set
  `target_dataslot_id / slotoffset / bridgeaddr / length`, pulse `target_dataslot_read`
  (rising-edge), wait for `ack`, then `done`, check `err[2:0]`. Data arrives as bridge
  writes at the chosen `bridgeaddr`, which the core captures.
- This is reliable at launch and for repeated reads of *different offsets within the
  same file* (our core reads one ~66 KB record per track from a multi-MB pack, and
  seeks freely — next/previous/shuffle/album-jump — with no issues for the whole
  session).

## 3. Observed behavior (hardware, multiple firmware versions)

| Action | Result |
|---|---|
| Launch core, pick file A | Reads work; playback/UI fully functional |
| Seek/read any offset within A | Works indefinitely |
| Open menu, pick a **different** file B (same slot) | Slot **size** updates (entry count refreshes) — but every `target_dataslot_read` for B **never completes** (no ack, no done) |
| Relaunch core, pick B at launch | Works perfectly |

Notably: **selection/positional data stays correct** — the size is right, so the core
knows how many entries B has; it simply cannot read any bytes of B.

## 4. What is *not* the cause (ruled out)

- **Not an EOF-alignment issue.** A separate, confirmed bug is that a
  `target_dataslot_read` whose last byte lands exactly on end-of-file never completes
  and wedges the command channel; we fixed that by always reading `min(chunk,
  remaining−2)` and never using `length = 0xFFFFFFFF`. The re-pick failure persists
  even with EOF-safe reads.
- **Not a core-side FSM wedge.** We added a ~1.8 s watchdog inside `core_bridge_cmd`'s
  `TARG_ST_WAITRESULT_DSO` state (the stock handler has **no timeout** and will hang
  forever on an unanswered command) plus retry logic; the core recovers and retries
  cleanly, but the reads still never complete — so the stall is on the APF/host side,
  not in our command-issuing FSM.
- **Not a boot-race timing issue.** We tried deferring reads ~450 ms after
  `dataslot_update`, and retrying for up to ~45 s. No amount of waiting helps (a
  healthy launch read completes in < 1 s, so waiting 45 s and failing is strong
  evidence the handle is dead, not busy).
- **Not the core's own loader corrupting state.** We gate the core's data path off
  during any host-initiated activity; playback of file A is unaffected right up until
  the read of B is attempted.

## 5. `getfile` / `openfile` — attempted remedy and exact results

The docs suggest a slot's file can be (re)opened with:

- **`getfile` (0x0190):** host writes the slot's current full path (256-byte,
  null-terminated) into a core-provided bridge buffer (`target_buffer_resp_struct`).
- **`openfile` (0x0192):** host reads a param struct from a core-provided buffer
  (`target_buffer_param_struct`: path[256] @0x0, flags u32 @0x100, size u32 @0x104)
  and opens that file into the slot; docs say "after opening, the slot becomes
  accessible via other Target read/write commands."

Findings on hardware:

1. With the struct buffer mapped at a high bridge address **near the reserved
   `0xF8xxxxxx` region** (we used `0xF0000000`): `getfile` **completes with `err = 0`
   but writes nothing** — the core's buffer stays all-zero. (Confirmed by displaying
   the buffer bytes on screen: all blanks.)
2. Relocating the struct buffer to a **low address (`0x40000000`)**: `getfile` now
   **delivers the correct path** (verified on-screen, e.g.
   `/Assets/spc/common/<name>.spcpak`, clean and complete).
3. Feeding that exact, correct path straight back to `openfile`: `openfile` returns
   **`err = 4` ("malformed path")** — on a path the host itself just produced.

So `getfile` is address-sensitive in an undocumented way, and `openfile` rejects a
path that round-trips from the host's own `getfile`. We could not get the documented
re-open sequence to work.

## 6. Corroborating evidence

- **No shipping core appears to do mid-session file swaps on a deferload slot.** The
  PC Engine CD core (Mazamars312), the most prominent user of `deferload` +
  `target_dataslot_read` (for CD sector streaming), does **not** support changing the
  disc's `.cue`/`.bin` mid-session — it displays an OSD error on a data-slot change.
- agg23's `openfpga-litex` wires up `getfile`/`openfile` as SDK plumbing, but we have
  no evidence they're exercised for a mid-session re-open in a shipping core.

This absence suggests the capability may simply never have worked as documented, and
that everyone has designed around it — which is what we ended up doing.

## 7. Current workaround (shipped)

- **One library pack.** Concatenate the user's whole collection into a single indexed
  file, picked once at launch; navigate inside the core (album/track browser). This
  sidesteps re-pick entirely and is arguably a nicer UX.
- **Relaunch to switch files.** The launch-time load path is 100% reliable, so
  "change file = quit + relaunch the core" (a few seconds) always works.

## 8. Open questions / avenues for future investigation

1. **Is the struct-buffer address the whole story for `getfile`?** It failed near
   `0xF8` and worked at `0x40000000`. Is there a documented/undocumented constraint on
   where `target_buffer_param_struct` / `target_buffer_resp_struct` may point? Is there
   a minimum alignment or a forbidden range beyond the obvious `0xF8xxxxxx` command
   block?
2. **Why does `openfile` call a valid, host-produced path "malformed" (err 4)?**
   - Does it require a specific root/prefix (relative vs absolute, a
     platform/assets-relative path rather than the full `/Assets/...`)?
   - Does it choke on spaces or specific characters in the filename? (Our test paths
     contained spaces.)
   - Are the `flags` (@0x100) / `size` (@0x104) fields interpreted even when zero, such
     that a plain "open existing, read-only" needs a non-zero flag?
   - Is the 256-byte path field expected to be exactly null-terminated with defined
     content beyond the terminator?
3. **Does the newest Pocket firmware behave differently?** We saw the same failure on
   more than one firmware version, but a systematic matrix (firmware × command × buffer
   address) has not been run.
4. **Is there a different, correct re-open sequence?** e.g. does a fresh
   `Reset Enter/Exit`, or a specific host-command interaction, re-arm the slot's file
   handle without relaunching? Does clearing/re-reading the data table matter?
5. **What exactly is the failure mode of the read after re-pick** — is the command
   never delivered to the host at all, or delivered and dropped? Instrumenting the SPI
   bridge traffic (logic analyzer on the Aristotle bridge, or the APF-side debug UART)
   would distinguish "host never sees the command" from "host sees it but has no valid
   handle."
6. **Community knowledge.** Has anyone made mid-session file re-pick on a `deferload`
   slot actually work? A concrete working `getfile`→`openfile`→`read` example, or
   confirmation from Analogue that it is unsupported, would close this out.

## 9. Minimal reproduction

1. Core with one `deferload` slot; read a record at launch → works.
2. Open menu, pick a different file for that slot.
3. Observe: data table size updates; `target_dataslot_read` on the slot never
   asserts `ack` or `done`.
4. `getfile` (buffer at a low bridge address) returns the correct new path;
   `openfile` with that path returns `err = 4`.
5. Relaunch the core, pick the same file at launch → works.

Instrument by rendering, on the core's own video output: the FSM state, the last
`target_dataslot_err`, and the raw bytes of the `getfile` buffer. (This on-screen
diagnostic is how the above was characterized without JTAG.)

---

*Filed from the SPC Pocket Player project (`carlosbravoa/spc-pocket-player`). Corrections
and reproductions welcome — especially a working mid-session re-open sequence.*
