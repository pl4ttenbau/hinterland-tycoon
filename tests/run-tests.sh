#!/bin/sh
set -eu

verbose=
only=
for arg in "$@"; do
    case "$arg" in
        -v|--verbose) verbose=--verbose ;;
        -h|--help)
            printf 'Usage: %s [-v|--verbose] [TEST...]\n' "$0"
            printf '%s\n' '  -v, --verbose  pass --verbose to Godot (e.g. to list leaked instances)' \
                '  TEST           run only these tests, e.g. road_vehicle or road_vehicle_test' \
                '                 (such a run keeps the other logs in tmp/)'
            exit 0
            ;;
        -*) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
        *)
            # Accept road_vehicle, road_vehicle_test, or a path like tests/road_vehicle_test.gd.
            name=${arg##*/}
            name=${name%.gd}
            name=${name%.tscn}
            case "$name" in *_test) ;; *) name=${name}_test ;; esac
            only="$only $name"
            ;;
    esac
done

project_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
cd "$project_dir"

for name in $only; do
    if [ ! -f "tests/$name.gd" ] && [ ! -f "tests/$name.tscn" ]; then
        printf 'No such test: %s\n' "$name" >&2
        exit 2
    fi
done

godot_bin=${GODOT_BIN:-$(command -v godot4 || command -v godot || true)}
if [ -z "$godot_bin" ]; then
    godot_bin=/home/cornelinux/Apps/Godot_v4.7.2-stable_linux.x86_64
fi
if ! command -v "$godot_bin" >/dev/null 2>&1; then
    printf '%s\n' 'Godot 4 executable not found. Set GODOT_BIN to its path.' >&2
    exit 1
fi

# Logs go to the project's git-ignored tmp/ folder, which every full run empties first.
# A run of selected tests only replaces those tests' logs.
logs="$project_dir/tmp"
mkdir -p "$logs"
[ -n "$only" ] || find "$logs" -mindepth 1 -delete
chmod 755 "$logs"
export XDG_DATA_HOME="$logs/user-data"
passed=0
failed=0
printf 'Logs: %s\n' "$logs"

# Headless runs do not rescan scripts, so new or renamed class_names stay unknown
# until the editor updates its class cache. --import does that scan and quits.
printf '%s\n' 'Refreshing script class cache...'
if ! "$godot_bin" --headless --path . --import >"$logs/_import.log" 2>&1; then
    printf '%s\n' "Class cache refresh reported errors, see $logs/_import.log" >&2
fi

for test in tests/*_test.gd tests/*_test.tscn; do
    [ -f "$test" ] || continue
    name=${test##*/}
    name=${name%.*}
    if [ -n "$only" ]; then
        case " $only " in
            *" $name "*) ;;
            *) continue ;;
        esac
    fi
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
        infrastructure_collision_test|road_vehicle_test|road_routing_test|road_junction_route_test|road_route_transfer_test|road_uturn_test|station_creator_test)
            set -- --fixed-fps 60 "$@"
            ;;
    esac

    set -- "$godot_bin" --headless --path . ${verbose:+"$verbose"} "$@" -- --no-mcp
    if command -v timeout >/dev/null 2>&1; then
        set -- timeout 120s "$@"
    fi
    started=$(date +%s)
    status=0
    "$@" >"$logs/$name.log" 2>&1 || status=$?
    elapsed=$(($(date +%s) - started))
    if [ "$status" -eq 0 ]; then
        result=PASS
        passed=$((passed + 1))
    else
        # timeout exits with 124 when it had to stop a test that never quit.
        [ "$status" -eq 124 ] && result=TIMEOUT || result=FAIL
        failed=$((failed + 1))
    fi
    printf '%-8s %-34s %4ss\n' "$result" "$name" "$elapsed"
done

printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
