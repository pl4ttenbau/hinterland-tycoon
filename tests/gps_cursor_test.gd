extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var suite: GDScript = load("res://tests/gps_cursor_suite.gd")
	if suite == null or not suite.can_instantiate():
		quit(1)
		return
	root.add_child(suite.new())
