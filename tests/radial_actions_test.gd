extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
	create_timer(30.0).timeout.connect(func(): quit(1))
func _run() -> void:
	var script: GDScript = load("res://tests/radial_actions_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var suite: Node = script.new()
	root.add_child(suite)
	await suite.run()
