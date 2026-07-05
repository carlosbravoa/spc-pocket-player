#!/bin/bash
# Create one .spcpak per folder of .spc files.
#
# Usage: pack_all.sh <music-root> [output-dir] [--default-length SECONDS]
#
#   music-root   directory whose subfolders each hold one album's .spc files
#                (the root itself is also packed if it has loose .spc files)
#   output-dir   where the .spcpak files go (default: <music-root>)
#
# Example:
#   pack_all.sh ~/spc /media/sd/Assets/spc/common
#   -> "Chrono Trigger.spcpak", "F-Zero.spcpak", ... one per subfolder
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
EXTRA_ARGS=("$@")     # e.g. --default-length 240

[ -d "$ROOT" ] || { echo "error: '$ROOT' is not a directory" >&2; exit 1; }
mkdir -p "$OUT"

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
