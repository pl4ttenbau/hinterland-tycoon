#!/usr/bin/env bash
set -eu

project_dir="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
godot_bin="${GODOT_BIN:-$(command -v godot4 || command -v godot || true)}"
if [[ -z "$godot_bin" ]]; then
    printf '%s\n' 'Godot 4 was not found on PATH. Set GODOT_BIN to the Godot executable.' >&2
    exit 1
fi

exec "$godot_bin" --headless --path "$project_dir" \
    --script res://tools/minerals/generate_mineral_maps.gd -- --no-mcp "$@"
