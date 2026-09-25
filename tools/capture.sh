#!/usr/bin/env bash
# capture.sh — Movie Maker gameplay capture (uses capture.gd beside this script)
# <project_dir> <out_dir> [frames]  -> PNG frames of real gameplay
set -euo pipefail
P=$(realpath "$1"); OUT=$(realpath -m "$2"); N=${3:-450}
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$(dirname "$0")/capture.gd" "$P/.capture_driver.gd"
cd "$P" && DISPLAY=${DISPLAY:-:1} timeout 180 godot --path . -s res://.capture_driver.gd --write-movie "$OUT/f.png" --fixed-fps 30 --quit-after "$N" >"$OUT/log.txt" 2>&1 || true
rm -f "$P/.capture_driver.gd" "$P/.capture_driver.gd.uid"
ls "$OUT"/*.png | wc -l
