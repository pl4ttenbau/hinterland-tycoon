@tool
@icon("res://assets/icons/icon_data.png")
class_name GeneratedInfrContainer extends Node3D

@export_group("Infr. Actions")
@export_tool_button("Empty Infr.")
var empty_infr = Callable(self, "do_empty_infr")

@export_tool_button("Generate Rail Tracks")
var gen_tracks = Callable(self, "do_generate_rail_tracks")

@export_tool_button("Generate Road Ways")
var gen_roads = Callable(self, "do_generate_road_ways")

func _ready() -> void:
	if Engine.is_editor_hint():
		self.owner = EditorInterface.get_edited_scene_root()

func add_rail(line3d: EditorInfrLine3D, _owner: Node):
	$EditorRails.add_child(line3d)
	line3d.owner = _owner

func add_road(line3d: EditorInfrLine3D, _owner: Node):
	$EditorRoads.add_child(line3d)
	line3d.owner = _owner
	
#region Button Action
func do_empty_infr() -> void:
	for child in $EditorRails.get_children():
		if child is Path3D: child.queue_free()
	for child in $EditorRoads.get_children():
		if child is Path3D: child.queue_free()
		
func do_generate_rail_tracks():
	var generator := WorldTracksGenerator.new()
	generator.spawn_track_paths()
	generator.queue_free()
	
func do_generate_road_ways():
	var generator := WorldRoadsGenerator.new()
	generator.spawn_road_paths()
	generator.queue_free()
#endregion

func _get_configuration_warnings() -> PackedStringArray:
	var err_msg_arr: PackedStringArray = []
	if !$EditorRails:
		err_msg_arr.append("EditorRails (GeneratedRailLines) child node missing")
	if !$EditorRoads:
		err_msg_arr.append("EditorRoads (GeneratedRoadWays) child node missing")
	return err_msg_arr
