@tool
@warning_ignore("missing_tool")
@icon("res://assets/icons/icon_gears_white.png")
class_name WorldTriggers extends TriggerManager

func _enter_tree() -> void:
	if ! Engine.is_editor_hint():
		Managers.triggers = self
