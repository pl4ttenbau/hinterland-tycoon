extends SceneTree

# Load the suite after the goods catalog autoload is available.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: GDScript = load("res://tests/industry_production_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = script.new()
	var result: Variant = suite.run()
	quit(result if result is int else 1)
