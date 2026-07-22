#!/bin/bash
# Rebuild PNGs from SVGs across all silhouette source directories.
# Each source gets a png/ subdirectory alongside its SVGs.
set -euo pipefail

INKSCAPE="/Applications/Inkscape.app/Contents/MacOS/inkscape"
WIDTH="${WIDTH:-512}"
REPO="$(cd "$(dirname "$0")/../.." && pwd)"

total=0; done_=0; failed=0

run_source() {
  local label="$1" svg_dir="$2"
  local png_dir="${svg_dir}/png"
  mkdir -p "$png_dir"

  local svgs=("$svg_dir"/*.svg)
  local count=${#svgs[@]}
  echo ""
  echo "── $label ($count SVGs → $png_dir)"

  for f in "${svgs[@]}"; do
    [ -f "$f" ] || continue
    stem=$(basename "$f" .svg)
    out="$png_dir/${stem}.png"
    total=$((total + 1))
    if "$INKSCAPE" --export-type=png --export-width="$WIDTH" -o "$out" "$f" 2>/dev/null; then
      done_=$((done_ + 1))
      echo "  ✓ $stem"
    else
      failed=$((failed + 1))
      echo "  ✗ $stem (failed)"
    fi
  done
}

run_source "App silhouettes"  "$REPO/apps/mobile_flutter/assets/silhouettes"
run_source "~/symbols/animals" "$HOME/symbols/animals"
run_source "~/symbols/plants"  "$HOME/symbols/plants"

echo ""
echo "Done: $done_/$total exported, $failed failed"
