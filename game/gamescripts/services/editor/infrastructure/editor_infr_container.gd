@tool
@icon("res://assets/icons/icon_data.png")
class_name GeneratedInfrContainer extends Node3D

@export_group("Infr. Actions")
@export_tool_button("Empty Infr.")
var empty_infr = Callable(self, "do_empty_infr")

func _ready() -> void:
	if Engine.is_editor_hint():
		self.owner = EditorInterface.get_edited_scene_root()
	else:
		self.visible = false
	
#region Button Action
func do_empty_infr() -> void:
	$EditorRails.clear()
	$EditorRoads.clear()
#endregion

func _get_configuration_warnings() -> PackedStringArray:
	var err_msg_arr: PackedStringArray = []
	if !$EditorRails:
		err_msg_arr.append("EditorRails (GeneratedRailLines) child node missing")
	if !$EditorRoads:
		err_msg_arr.append("EditorRoads (GeneratedRoadWays) child node missing")
	return err_msg_arr
