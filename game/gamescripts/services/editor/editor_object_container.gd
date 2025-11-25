@tool
@icon("res://assets/icons/icon_editor.png")
class_name EditorObjectContainer extends Node3D

@export_tool_button("Empty Infr.")
var empty_infr = Callable(self, "do_empty_infr")

func _ready():
	if ! Engine.is_editor_hint():
		self.visible = false

func do_empty_infr() -> void:
	for child in $EditorInfr.get_children():
		if child is Path3D:
			child.queue_free()
