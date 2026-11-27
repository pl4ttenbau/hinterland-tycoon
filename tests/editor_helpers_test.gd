extends SceneTree
## Runner only: the suite uses editor classes that need autoloads (GlobalState, Managers, ...), which do
## not exist yet when a --script file is compiled. Loading the suite at runtime defers that compile.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: GDScript = load("res://tests/editor_helpers_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = script.new()
	var result: Variant = await suite.run(self)
	quit(result if result is int else 1)
