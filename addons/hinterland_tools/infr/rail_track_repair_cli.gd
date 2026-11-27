## Command-line launcher for the rail track commands: repair (plan or --write) and the fork report (forks).
##
##   tools/rail/tracks.sh <repair | forks> --map <map_key> [--write]
##
## Usage and details are in rail_track_repair_tool.gd.
##
## Only a launcher. A --script file is compiled before the project's autoloads exist, so it must not name
## classes that need them; the fork report reaches some through RoadEndpointConnection. The actual work is
## in rail_track_repair_tool.gd, loaded at runtime once the autoloads are up.
extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: GDScript = load("res://addons/hinterland_tools/infr/rail_track_repair_tool.gd")
	if script == null or not script.can_instantiate():
		printerr("Cannot load rail_track_repair_tool.gd.")
		quit(1)
		return
	var tool: RefCounted = script.new()
	quit(tool.run(OS.get_cmdline_user_args()))
