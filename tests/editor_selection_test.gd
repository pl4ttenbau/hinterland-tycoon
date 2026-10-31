extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var script: GDScript = load("res://tests/editor_selection_suite.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var result: Variant = script.new().run(self)
	quit(result if result is int else 1)
