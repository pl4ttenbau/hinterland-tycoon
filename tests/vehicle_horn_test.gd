extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var script: GDScript = load("res://tests/vehicle_horn_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: RefCounted = script.new()
	var result: Variant = await suite.run(self)
	# Let the completed coroutine release fixture and resource references before exit.
	suite = null
	quit.call_deferred(result if result is int else 1)
