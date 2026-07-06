#!/bin/bash
# Create one .spcpak per folder of .spc files, or one indexed library pack.
#
# Usage: pack_all.sh <music-root> [output-dir] [--library] [--default-length SECONDS]
#
#   music-root   directory whose subfolders each hold one album's .spc files
#                (the root itself is also packed if it has loose .spc files)
#   output-dir   where the .spcpak files go (default: <music-root>)
#   --library    pack EVERYTHING into a single "<root>.spcpak" with one
#                album per subfolder (browse with L1/R1 on the core)
#
# Examples:
#   pack_all.sh ~/spc /media/sd/Assets/spc/common
#   -> "Chrono Trigger.spcpak", "F-Zero.spcpak", ... one per subfolder
#   pack_all.sh ~/spc /media/sd/Assets/spc/common --library
#   -> one "spc.spcpak" containing every album
set -euo pipefail

TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
MAKE_PAK="$TOOLS_DIR/make_spcpak.py"

if [ $# -lt 1 ]; then
    grep '^#' "$0" | sed 's/^# \?//' | head -12
    exit 1
fi

ROOT="$1"; shift
OUT="$ROOT"
if [ $# -ge 1 ] && [ "${1#--}" = "$1" ]; then
    OUT="$1"; shift
fi
LIBRARY=0
EXTRA_ARGS=()
for a in "$@"; do
    if [ "$a" = "--library" ]; then LIBRARY=1; else EXTRA_ARGS+=("$a"); fi
done

[ -d "$ROOT" ] || { echo "error: '$ROOT' is not a directory" >&2; exit 1; }
mkdir -p "$OUT"

if [ "$LIBRARY" = 1 ]; then
    # one indexed pack of everything: each album folder is one argument
    dirs=()
    while IFS= read -r -d '' dir; do
        shopt -s nullglob nocaseglob
        spcs=("$dir"/*.spc)
        shopt -u nullglob nocaseglob
        [ ${#spcs[@]} -gt 0 ] && dirs+=("$dir")
    done < <(find "$ROOT" -type d -print0 | sort -z)
    [ ${#dirs[@]} -gt 0 ] || { echo "no .spc files found" >&2; exit 1; }
    name="$(basename "$(cd "$ROOT" && pwd)")"
    python3 "$MAKE_PAK" "${dirs[@]}" -o "$OUT/$name.spcpak" "${EXTRA_ARGS[@]}"
    exit 0
fi

packed=0
skipped=0

# every directory under (and including) ROOT that directly contains .spc files
while IFS= read -r -d '' dir; do
    shopt -s nullglob nocaseglob
    spcs=("$dir"/*.spc)
    shopt -u nullglob nocaseglob
    if [ ${#spcs[@]} -eq 0 ]; then
        continue
    fi

    if [ "$dir" = "$ROOT" ]; then
        name="$(basename "$(cd "$ROOT" && pwd)")"
    else
        name="$(basename "$dir")"
    fi

    target="$OUT/$name.spcpak"
    echo "=== $name (${#spcs[@]} songs) ==="
    if python3 "$MAKE_PAK" "$dir" -o "$target" "${EXTRA_ARGS[@]}"; then
        packed=$((packed + 1))
    else
        echo "  FAILED: $dir" >&2
        skipped=$((skipped + 1))
    fi
done < <(find "$ROOT" -type d -print0 | sort -z)

echo
echo "done: $packed pack(s) written to $OUT${skipped:+, $skipped failed}"
