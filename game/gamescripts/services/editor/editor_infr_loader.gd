@tool
extends EditorScript

const MAP_KEY = "harzmountains" # change here
const TRACKS_JSON_PATH_FORMAT = "res://world/%s/jsondata/tracks.json"
const ROADS_JSON_PATH_FORMAT = "res://world/%s/jsondata/roads.json"


@export_storage var parent: Node3D:
	get():
		var infr_container = get_scene().find_child("EditorInfr", true)
		if ! infr_container:
			push_error("Cannt find Node \"EditorInfr\"")
		return infr_container

func _run():
	self.clear_editor_tracks()
	self.spawn_track_paths()
	self.spawn_road_paths()

func clear_editor_tracks():
	for child: Node in self.parent.get_children():
		child.queue_free()

#region Rail Path Spawning
func spawn_track_paths():
	var file_path := TRACKS_JSON_PATH_FORMAT % MAP_KEY
	var rails_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	for track_dict: Dictionary in rails_json_arr:
		self.spawn_single_track_path(track_dict)
		
func spawn_single_track_path(track_data_dict: Dictionary):
	var track_num: int = track_data_dict.get("num")
	var path: Path3D = Path3D.new()
	path.name = "Editor_Track%d" % track_num
	path.set_meta("track_num", track_num)
	path.set_meta("name", track_data_dict.get("name", null))
	path.curve = Curve3D.new()
	for point in track_data_dict.points:
		path.curve.add_point(vec3_from_float_arr(point.pos))
	self.parent.add_child(path, true)
	path.owner = get_scene()
#endregion

#region Road Path Spawning
func spawn_road_paths():
	var file_path := ROADS_JSON_PATH_FORMAT % MAP_KEY
	var roads_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	for road_dict: Dictionary in roads_json_arr:
		self.spawn_road_track_path(road_dict)
		
func spawn_road_track_path(road_data_dict: Dictionary):
	var road_num: int = road_data_dict.get("num")
	var path: Path3D = Path3D.new()
	path.name = "Editor_Road%d" % road_num
	path.set_meta("road_num", road_num)
	path.set_meta("name", road_data_dict.get("name", null))
	# create curve
	path.curve = Curve3D.new()
	for point in road_data_dict.points:
		path.curve.add_point(vec3_from_float_arr(point.pos))
	# add as parent and to editor scene
	self.parent.add_child(path, true)
	path.owner = get_scene()
#endregion

func vec3_from_float_arr(float_arr: Array):
	var vec3: Vector3 = Vector3()
	if (float_arr == null || typeof(float_arr) != TYPE_ARRAY):
		push_error("could not convert %s to Vector3" % float_arr)
		return
	return Vector3(float_arr[0], float_arr[1], float_arr[2])
