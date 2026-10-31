extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	# Delay script loading until the project's autoload names are registered.
	var suite: GDScript = load("res://tests/infr_drawing_suite.gd")
	if suite == null or not suite.can_instantiate():
		quit(1)
		return
	var result: Variant = suite.new().run(self)
	quit(result if result is int else 1)
