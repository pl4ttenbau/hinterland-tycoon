@tool
@icon("res://assets/icons/icon_editor.png")
class_name EditorObjectContainer extends Node3D

@export var has_infr_loaded: bool:
	get():
		return $EditorInfr.get_children().size() >= 0
		
@export_group("Infr. Actions")
@export_tool_button("Empty Infr.")
var empty_infr = Callable(self, "do_empty_infr")

#region Initializaion
func _ready():
	if ! Engine.is_editor_hint(): self._ingame_ready()
	else: self._editor_ready()

func _editor_ready():
	pass
	
func _ingame_ready():
	self.visible = false
#endregion

#region Button Action
func do_empty_infr() -> void:
	for child in $EditorInfr.get_children():
		if child is Path3D: child.queue_free()
#endregion
