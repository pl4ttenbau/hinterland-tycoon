@tool
extends EditorScript

const MAP_KEY = "harzmountains" # change here
const TRACKS_JSON_PATH_FORMAT = "res://world/%s/jsondata/tracks.json"

@export_storage var parent: Node3D:
	get():
		var infr_container = get_scene().find_child("EditorInfr", true)
		if ! infr_container:
			push_error("Cannt find Node \"EditorInfr\"")
		return infr_container

func _run():
	self.clear_editor_tracks()
	self.spawn_track_paths()

func clear_editor_tracks():
	for child: Node in self.parent.get_children():
		child.queue_free()

# aus dem RailLoader
func spawn_track_paths():
	var file_path := TRACKS_JSON_PATH_FORMAT % MAP_KEY
	var rails_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	for track_dict: Dictionary in rails_json_arr:
		var track_num: int = track_dict.get("num")
		var path: Path3D = Path3D.new()
		path.name = "EditorTrack_Path_%d" % track_num
		path.set_meta("track_num", track_num)
		path.curve = Curve3D.new()
		for point in track_dict.points:
			var vec3: Vector3 = vec3_from_float_arr(point.pos)
			path.curve.add_point(vec3)
		self.parent.add_child(path, true)
		path.owner = get_scene()

func vec3_from_float_arr(float_arr: Array):
	var vec3: Vector3 = Vector3()
	if (float_arr == null || typeof(float_arr) != TYPE_ARRAY):
		push_error("could not convert %s to Vector3" % float_arr)
		return
	return Vector3(float_arr[0], float_arr[1], float_arr[2])
