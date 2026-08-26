#!/usr/bin/env bash
# Pixel Skies verification. Usage:
#   ./verify.sh              import + full test suite
#   ./verify.sh shots [name] import + tests + render capture scenario (default: world_opening)
set -euo pipefail
cd "$(dirname "$0")"

GODOT="${GODOT:-$HOME/godot-editor/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$GODOT" ]; then
  echo "Godot 4.7.x not found at $GODOT (override with GODOT=...)" >&2
  exit 1
fi

# A rescan is required whenever a new class_name global appears, otherwise the
# parser reports phantom "Could not find type" errors.
echo "== import =="
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true

echo "== tests =="
set +e
"$GODOT" --headless --path . --script res://scripts/dev/run_tests.gd 2>&1 \
  | grep -vE '^\s*$|Godot Engine v' | grep -v $'\033'
status=${PIPESTATUS[0]}
set -e

if [ "${1:-}" = "shots" ]; then
  echo "== capture: ${2:-world_opening} =="
  # Captures need a real renderer, so this runs windowed rather than headless.
  "$GODOT" --path . -- --scenario "${2:-world_opening}" 2>&1 | grep '\[capture\]' || true
fi

exit "$status"
