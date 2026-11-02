extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: GDScript = load("res://tests/rail_vehicle_pricing_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = script.new()
	var result: Variant = await suite.run(self)
	quit(result if result is int else 1)
