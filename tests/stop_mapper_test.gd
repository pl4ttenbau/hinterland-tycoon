extends SceneTree
## Runner only: the suite builds stop and interchange Resources, which reaches autoload-dependent classes that a --script file
## cannot name at compile time. The suite is loaded once the autoloads exist.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: GDScript = load("res://tests/stop_mapper_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = script.new()
	quit(suite.run(self))
