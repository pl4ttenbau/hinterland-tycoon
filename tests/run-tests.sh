#!/bin/sh
set -eu

project_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$project_dir"

godot_bin=${GODOT_BIN:-$(command -v godot4 || command -v godot || true)}
if [ -z "$godot_bin" ]; then
    godot_bin=/home/cornelinux/Apps/Godot_v4.7.2-stable_linux.x86_64
fi
if ! command -v "$godot_bin" >/dev/null 2>&1; then
    printf '%s\n' 'Godot 4 executable not found. Set GODOT_BIN to its path.' >&2
    exit 1
fi

logs=$(mktemp -d "${TMPDIR:-/tmp}/hinterland-tests.XXXXXX")
export XDG_DATA_HOME="$logs/user-data"
passed=0
failed=0
printf 'Logs: %s\n' "$logs"

for test in tests/*_test.gd tests/*_test.tscn; do
    [ -f "$test" ] || continue
    name=${test##*/}
    name=${name%.*}
    case "$test" in
        *.gd)
            # The scene initializes any required nodes and runs the attached script.
            [ ! -f "${test%.gd}.tscn" ] || continue
            set -- --script "res://$test"
            ;;
        *.tscn)
            set -- "res://$test"
            ;;
    esac
    case "$name" in
        infrastructure_collision_test|road_vehicle_test|road_routing_test|road_route_transfer_test|road_uturn_test|station_creator_test)
            set -- --fixed-fps 60 "$@"
            ;;
    esac

    set -- "$godot_bin" --headless --path . "$@" -- --no-mcp
    if command -v timeout >/dev/null 2>&1; then
        set -- timeout 120s "$@"
    fi
    if "$@" >"$logs/$name.log" 2>&1; then
        printf 'PASS  %s\n' "$name"
        passed=$((passed + 1))
    else
        printf 'FAIL  %s\n' "$name"
        failed=$((failed + 1))
    fi
done

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
