extends SceneTree

# Defer suite loading until the catalog and other autoloads are ready.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(20).timeout.connect(func(): quit(1))
	var script: GDScript = load("res://tests/passenger_spawning_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = script.new()
	var result: Variant = suite.run(self)
	quit(result if result is int else 1)
