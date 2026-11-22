## Command-line front end for RailTrackRepair: plans by default, writes only with --write.
##
##   Plan (read-only, prints what would change):
##     godot --headless --path . --script res://addons/hinterland_tools/infr/rail_track_repair_cli.gd -- mpsb
##   Apply (writes world/<map>/jsondata/tracks.json, keeping a timestamped .bak- copy next to it):
##     godot --headless --path . --script res://addons/hinterland_tools/infr/rail_track_repair_cli.gd -- mpsb --write
##
## Writing goes through InfrJsonStore.write_with_backup, the same path as saving from the editor: the
## records are validated, positions rounded to centimetres and handles to millimetres, the new file is
## written to a temporary file first, and the original is only replaced once the backup exists.
## Exit code 0 on success (including "nothing to repair"), 1 on any error.
extends SceneTree

const USAGE: String = "Usage: godot --headless --path . --script res://addons/hinterland_tools/infr/rail_track_repair_cli.gd -- <map_key> [--write]"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var write: bool = args.has("--write")
	var map_key: String = ""
	for arg: String in args:
		if not arg.begins_with("--"):
			map_key = arg
	## Same rule as InfrJsonStore.path_for: a bare folder name, never a path.
	if map_key.is_empty() or map_key.get_file() != map_key or map_key in [".", ".."]:
		printerr(USAGE)
		quit(1)
		return
	var path: String = InfrJsonStore.INFR_JSON_PATH_TEMPLATE % [map_key, "tracks"]
	var source: InfrCatalogReadResult = InfrJsonStore.read_records(path)
	if not source.ok or not source.exists:
		printerr("Cannot read %s: %s" % [path, source.error if not source.ok else "file does not exist"])
		quit(1)
		return
	var result: Dictionary = RailTrackRepair.repair(source.records)
	print("Rail track repair for %s (%s)" % [map_key, "WRITING" if write else "plan only, nothing written"])
	for line: String in result.report:
		print("  " + line)
	var changed: bool = result.duplicates > 0 or result.aligned > 0
	if not write:
		if changed:
			print("Run again with --write to apply. The original is kept as a .bak- copy.")
		quit(0)
		return
	if not changed:
		print("Nothing to repair; %s left untouched." % path)
		quit(0)
		return
	var saved: EditorActionResult = InfrJsonStore.write_with_backup(path, result.records)
	if not saved.ok:
		printerr("Not written: " + saved.error)
		quit(1)
		return
	print("Written %s (backup: %s)." % [path, saved.backup])
	quit(0)
