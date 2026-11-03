extends SceneTree

# Share the isolated road fixture, but load only after singleton startup.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(600).timeout.connect(func(): quit(1))
	var script: GDScript = load("res://tests/road_uturn_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = script.new()
	var result: Variant = await suite.run(self)
	quit(result if result is int else 1)
