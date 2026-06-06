@tool
extends EditorPlugin

const Shared := preload("res://addons/GodotSignalChecker/scripts/shared.gd")

var editor_dock: EditorDock

# Plugin initialization.
func _enter_tree() -> void:
	_register_runtime_settings()

	editor_dock = EditorDock.new()
	editor_dock.name = "SignalChecker"
	editor_dock.title = Shared.DOCK_TITLE
	editor_dock.force_show_icon = true
	#dock.dock_icon = preload("./dock_icon.png")
	editor_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	
	var dock_content := preload("res://addons/GodotSignalChecker/scenes/signal_checker_dock.tscn").instantiate()
	dock_content.editor_dock = editor_dock
	
	editor_dock.add_child(dock_content)
	add_dock(editor_dock)

# Plugin clean-up.
func _exit_tree() -> void:
	if not editor_dock:
		return
	
	remove_dock(editor_dock)
	editor_dock.queue_free()
	editor_dock = null

func _register_runtime_settings() -> void:
	var changed: bool = false

	if not ProjectSettings.has_setting(Shared.SETTING_SCAN_PARAMETER):
		ProjectSettings.set_setting(Shared.SETTING_SCAN_PARAMETER, Shared.SETTING_SCAN_PARAMETER_DEFAULT)
		changed = true

	ProjectSettings.set_initial_value(Shared.SETTING_SCAN_PARAMETER, Shared.SETTING_SCAN_PARAMETER_DEFAULT)
	ProjectSettings.add_property_info({
		"name": Shared.SETTING_SCAN_PARAMETER,
		"type": TYPE_BOOL
	})

	if changed:
		ProjectSettings.save()
