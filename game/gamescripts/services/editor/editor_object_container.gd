@tool
@icon("res://assets/icons/icon_editor.png")
class_name EditorObjectContainer extends Node3D

@export_tool_button("Regenerate Infr.")
var position_action = do_empty_infr

func _ready():
	if ! Engine.is_editor_hint():
		self.visible = false

func do_empty_infr() -> void:
	pass
