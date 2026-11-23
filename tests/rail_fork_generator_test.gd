extends SceneTree
## Runner only: RailForkGenerator reaches autoload-dependent classes through RoadEndpointConnection, which
## a --script file cannot name at compile time. The suite is loaded once the autoloads exist.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: GDScript = load("res://tests/rail_fork_generator_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = script.new()
	quit(suite.run(self))
