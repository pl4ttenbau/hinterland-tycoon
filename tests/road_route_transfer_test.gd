extends SceneTree

# Load after singleton/catalog startup and fail closed on a hung integration test.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(60).timeout.connect(func(): quit(1))
	var script: GDScript = load("res://tests/road_route_transfer_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = script.new()
	var result: Variant = await suite.run(self)
	quit(result if result is int else 1)
