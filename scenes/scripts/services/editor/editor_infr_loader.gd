@tool
extends EditorScript

const json_path = "res://world/jsondata/tracks.json"

func _run():
	spawn_track_paths()

# aus dem RailLoader
func spawn_track_paths():
	var rails_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	for json_track: Dictionary in rails_json_arr:
		var path: Path3D = Path3D.new()
		path.curve = Curve3D.new()
		for point in json_track.points:
			var vec3: Vector3 = vec3_from_float_arr(point.pos)
			path.curve.add_point(vec3)
		get_parent().add_child(path)
		path.owner = get_scene()
			
func get_parent() -> Node3D:
	var infr_container = get_scene().get_node("World/InEditor/EditorInfr")
	if ! infr_container:
		push_error("Cannt find Node \"World/InEditor/EditorTowns\"")
	return infr_container

func vec3_from_float_arr(float_arr: Array):
	var vec3: Vector3 = Vector3()
	if (float_arr == null || typeof(float_arr) != TYPE_ARRAY):
		push_error("could not convert %s to Vector3" % float_arr)
		return
	return Vector3(float_arr[0], float_arr[1], float_arr[2])
