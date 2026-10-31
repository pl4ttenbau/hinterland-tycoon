extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Load after autoload initialization. Statically referencing the integration
	# suite from a --script entry point compiles its dependencies before singleton
	# names (Managers, GlobalState, Loggie) have been registered by SceneTree.
	var suite_script: GDScript = load("res://tests/infr_smoothing_suite.gd")
	if suite_script == null or not suite_script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = suite_script.new()
	var result: Variant = suite.run(self)
	# An aborted suite returns null; it must not silently turn into a passing exit.
	quit(result if result is int else 1)
