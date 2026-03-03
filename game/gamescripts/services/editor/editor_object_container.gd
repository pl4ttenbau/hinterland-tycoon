@tool
@icon("res://assets/icons/icon_editor.png")
class_name WorldEditorObjects extends Node3D

#region Initializaion
func _ready():
	if ! Engine.is_editor_hint(): 
		self._ingame_ready()
	else: 
		self._editor_ready()

func _editor_ready():
	pass
	
func _ingame_ready():
	self.visible = false
#endregion

func _get_configuration_warnings() -> PackedStringArray:
	if !$EditorInfr:
		return ["EditorInfr (GeneratedInfrContainer) child node missing"]
	return []
