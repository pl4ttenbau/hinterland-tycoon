## be careful - you can only run this script with the WorldMap (per exmaple MPSB) open
## do not try to run with the Empty "Worldscene" open
@tool
extends EditorScript

const TRACKS_JSON_PATH_FORMAT = "res://world/%s/jsondata/tracks.json"
const ROADS_JSON_PATH_FORMAT = "res://world/%s/jsondata/roads.json"

const RAIL_COLOR = Color.BLACK
const ROAD_COLOR = Color.DARK_ORANGE

@export_storage var editor_infr_node: Node3D:
	get():
		var infr_container = get_scene().find_child("EditorInfr", true)
		if ! infr_container: push_error("Cannt find Node \"EditorInfr\"")
		return infr_container

func _run():
	self.clear_editor_tracks()
	var map_name: String = get_map_name()
	if map_name:
		self.spawn_track_paths(map_name)
		self.spawn_road_paths(map_name)

func clear_editor_tracks():
	for child: Node in self.editor_infr_node.get_children():
		child.queue_free()

#region Rail Path Spawning
func spawn_track_paths(map_key: String):
	var file_path := TRACKS_JSON_PATH_FORMAT % map_key
	var rails_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	for track_dict: Dictionary in rails_json_arr:
		self.spawn_single_track_line(track_dict)
	
func spawn_single_track_line(track_data_dict: Dictionary) -> EditorInfrLine3D:
	var line3d := RailMapper.editor_line_from_data(track_data_dict)
	line3d.create_curve_from_dict(track_data_dict, true)
	# add as child & assign to editor scene
	self.editor_infr_node.add_child(line3d, true)
	line3d.owner = get_scene()
	return line3d
#endregion

#region Road Path Spawning
func spawn_road_paths(map_key: String):
	var file_path := ROADS_JSON_PATH_FORMAT % map_key
	var roads_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	for road_dict: Dictionary in roads_json_arr:
		self.spawn_road_line_3d(road_dict)
		
func spawn_road_line_3d(road_data_dict: Dictionary) -> LinePath3D:
	var line3d := RoadMapper.editor_line_from_data(road_data_dict)
	line3d.create_curve_from_dict(road_data_dict, false)
	# add as child & assign to editor scene
	self.editor_infr_node.add_child(line3d, true)
	line3d.owner = get_scene()
	return line3d
#endregion

#region Helper-Methods
func get_map_name():
	var editor_map_name = EditorUtils.get_editor_map_name()
	if ! editor_map_name:
		Loggie.error("Cannot generate editor infrastructure: cannot get open editor map")
		return null
	return editor_map_name
#endregion
