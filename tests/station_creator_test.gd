extends SceneTree

func _initialize() -> void:
	_run.call_deferred()
	create_timer(40.0).timeout.connect(func(): quit(1))

func _run() -> void:
	var script: GDScript = load("res://tests/station_creator_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: Node = script.new()
	root.add_child(suite)
	var completed: Variant = await suite.run()
	quit(0 if completed == true and suite.failures == 0 else 1)
