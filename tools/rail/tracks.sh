#!/bin/sh
# Rail track commands, without the Godot command line around them.
#
#   tools/rail/tracks.sh repair --map mpsb            plan only, prints what would change
#   tools/rail/tracks.sh repair --map mpsb --write    apply, keeping a .bak- copy of tracks.json
#   tools/rail/tracks.sh forks --map mpsb             compare the forks in the file with the geometry
#   tools/rail/tracks.sh forks --map mpsb --write     set the forks to what the geometry calls for
#
# All arguments go to rail_track_repair_cli.gd unchanged; see rail_track_repair_tool.gd for details.
set -eu

case "${1:-}" in
    ''|-h|--help)
        printf 'Usage: %s <repair | forks> --map <map_key> [--write]\n' "$0"
        [ -n "${1:-}" ] && exit 0 || exit 2
        ;;
esac

project_dir=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)

# Same lookup as tests/run-tests.sh: GODOT_BIN, then godot4/godot on PATH, then the usual local install.
godot_bin=${GODOT_BIN:-$(command -v godot4 || command -v godot || true)}
if [ -z "$godot_bin" ]; then
    godot_bin=/home/cornelinux/Apps/Godot_v4.7.2-stable_linux.x86_64
fi
if ! command -v "$godot_bin" >/dev/null 2>&1; then
    printf '%s\n' 'Godot 4 executable not found. Set GODOT_BIN to its path.' >&2
    exit 1
fi

# "--" ends Godot's own options: everything after it reaches the script via OS.get_cmdline_user_args().
exec "$godot_bin" --headless --path "$project_dir" \
    --script res://addons/hinterland_tools/infr/rail_track_repair_cli.gd -- "$@"
