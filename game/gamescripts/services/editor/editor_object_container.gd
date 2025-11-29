@tool
@icon("res://assets/icons/icon_editor.png")
class_name EditorObjectContainer extends Node3D

@export var has_infr_loaded: bool:
	get():
		return $EditorInfr.get_children().size() >= 0
		
@export_group("Infr. Actions")
@export_tool_button("Empty Infr.")
var empty_infr = Callable(self, "do_empty_infr")

func _ready():
	if ! Engine.is_editor_hint():
		self.visible = false

#region Button Action
func do_empty_infr() -> void:
	for child in $EditorInfr.get_children():
		if child is Path3D: child.queue_free()
#endregion
