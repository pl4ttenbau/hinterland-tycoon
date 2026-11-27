## The rail track commands behind rail_track_repair_cli.gd. Each only prints a plan unless --write is given.
##
## Shortcut: tools/rail/tracks.sh <command> --map <map_key> [--write] runs the same with Godot found for you.
##
##   repair: merge duplicate points and straighten slightly kinked joins.
##     godot --headless --path . --script res://addons/hinterland_tools/infr/rail_track_repair_cli.gd -- repair --map mpsb [--write]
##   forks: set every track end's switch (fork) to what the track geometry calls for (RailForkGenerator).
##     godot --headless --path . --script res://addons/hinterland_tools/infr/rail_track_repair_cli.gd -- forks --map mpsb [--write]
##
## With --write, the result replaces world/<map>/jsondata/tracks.json, keeping a .bak- copy next to it.
## Writing goes through InfrJsonStore.write_with_backup, the same path as saving from the editor: the
## records are validated, positions rounded to centimetres and handles to millimetres, the new file is
## written to a temporary file first, and the original is only replaced once the backup exists.
## Exit code 0 on success (including "nothing to change"), 1 on any error, 2 on bad arguments.
extends RefCounted

const USAGE: String = "Usage: tools/rail/tracks.sh <repair | forks> --map <map_key> [--write]"
const COMMANDS: Array[String] = ["repair", "forks"]

## Runs one command; returns the process exit code. `args` are the user arguments after "--".
func run(args: PackedStringArray) -> int:
	## The command comes first, then the options in any order. Anything unknown is refused rather than
	## ignored: a mistyped --write must not quietly turn a write into a plan, or the other way round.
	var command: String = args[0] if not args.is_empty() else ""
	var write: bool = false
	var map_key: String = ""
	var i: int = 1
	while i < args.size():
		match args[i]:
			"--write":
				write = true
			"--map":
				i += 1
				map_key = args[i] if i < args.size() else ""
			_:
				printerr("Unknown argument: %s\n%s" % [args[i], USAGE])
				return 2
		i += 1
	if not command in COMMANDS:
		printerr(USAGE)
		return 2
	## Same rule as InfrJsonStore.path_for: a bare folder name, never a path. Also catches a missing value
	## (--map at the end, or followed by another flag).
	if map_key.is_empty() or map_key.begins_with("--") or map_key.get_file() != map_key or map_key in [".", ".."]:
		printerr("Missing or invalid --map.\n" + USAGE)
		return 2
	var path: String = InfrJsonStore.INFR_JSON_PATH_TEMPLATE % [map_key, "tracks"]
	var source: InfrCatalogReadResult = InfrJsonStore.read_records(path)
	if not source.ok or not source.exists:
		printerr("Cannot read %s: %s" % [path, source.error if not source.ok else "file does not exist"])
		return 1
	## Both commands return {"records", "report"} plus their own counts; only "did anything change" differs.
	var result: Dictionary
	var changed: bool
	if command == "forks":
		result = RailForkGenerator.apply(source.records)
		changed = result.differ > 0
	else:
		result = RailTrackRepair.repair(source.records)
		changed = result.duplicates > 0 or result.aligned > 0
	print("Rail track %s for %s (%s)" % [command, map_key, "WRITING" if write else "plan only, nothing written"])
	for line: String in result.report:
		print("  " + line)
	if not write:
		if changed:
			print("Run again with --write to apply. The original is kept as a .bak- copy.")
		return 0
	if not changed:
		print("Nothing to change; %s left untouched." % path)
		return 0
	var saved: EditorActionResult = InfrJsonStore.write_with_backup(path, result.records)
	if not saved.ok:
		printerr("Not written: " + saved.error)
		return 1
	print("Written %s (backup: %s)." % [path, saved.backup])
	return 0
