@tool
@icon("res://assets/icons/nodes_3d/icon_data.svg")
class_name GeneratedInfrContainer extends Node3D

@export_group("Infr. Actions")
@export_tool_button("Empty Infr.")
var empty_infr = Callable(self, "do_empty_infr")

## Uses saved roads/tracks and terrain; save infrastructure JSON before rebuilding.
@export_tool_button("Regenerate Grass Map")
var regenerate_grass_map_button = Callable(self, "regenerate_grass_map")

var _grass_bake_running: bool = false

func regenerate_grass_map() -> void:
	if not Engine.is_editor_hint() or _grass_bake_running:
		return
	var tool_path: String = "res://tools/grass/grass_map_regenerator.gd"
	if not FileAccess.file_exists(tool_path):
		push_warning("Grass regeneration requires the optional local tools/grass folder.")
		return
	_grass_bake_running = true
	var regenerator: Script = load(tool_path)
	if regenerator == null or not regenerator.can_instantiate():
		push_error("Cannot load the local grass regeneration tool.")
		_grass_bake_running = false
		return
	await regenerator.regenerate(self)
	_grass_bake_running = false

func _ready() -> void:
	#if Engine.is_editor_hint():
	#	self.owner = EditorInterface.get_edited_scene_root()
	if !Engine.is_editor_hint():
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
