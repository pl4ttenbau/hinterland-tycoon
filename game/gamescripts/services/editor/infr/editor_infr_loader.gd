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
		
func spawn_single_track_path(track_data_dict: Dictionary) -> Path3D:
	var start_pos: Vector3 = WorldUtils.vec3_from_float_arr(track_data_dict.points[0].pos)
	var path := RailMapper.path3d_from_data(track_data_dict)
	path.position = start_pos
	path.curve = Curve3D.new()
	# create curve
	for point in track_data_dict.points:
		var abs_pos = WorldUtils.vec3_from_float_arr(point.pos)
		var rel_pos: Vector3 = abs_pos - start_pos
		path.curve.add_point(rel_pos)
	self.editor_infr_node.add_child(path, true)
	path.owner = get_scene()
	return path
	
func spawn_single_track_line(track_data_dict: Dictionary) -> LinePath3D:
	var start_pos: Vector3 = WorldUtils.vec3_from_float_arr(track_data_dict.points[0].pos)
	var line3d := RailMapper.line3d_from_data(track_data_dict)
	line3d.position = start_pos
	# create curve
	line3d.curve = Curve3D.new()
	for point in track_data_dict.points:
		var abs_pos = WorldUtils.vec3_from_float_arr(point.pos)
		var rel_pos: Vector3 = abs_pos - start_pos
		line3d.curve.add_point(rel_pos)
	self.editor_infr_node.add_child(line3d, true)
	line3d.owner = get_scene()
	# set color
	var line_mat: ShaderMaterial = line3d.material
	line_mat.set("shader_parameter/line_width", .25)
	line_mat.set("shader_parameter/color", RAIL_COLOR)
	return line3d
#endregion

#region Road Path Spawning
func spawn_road_paths(map_key: String):
	var file_path := ROADS_JSON_PATH_FORMAT % map_key
	var roads_json_arr: Array = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	for road_dict: Dictionary in roads_json_arr:
		self.spawn_road_line_3d(road_dict)
		
func spawn_road_track_path(road_data_dict: Dictionary) -> Path3D:
	var start_pos: Vector3 = WorldUtils.vec3_from_float_arr(road_data_dict.points[0].pos)
	var path: Path3D = RoadMapper.path3d_from_data(road_data_dict)
	path.position = start_pos
	# create curve
	path.curve = Curve3D.new()
	for point in road_data_dict.points:
		var abs_pos = WorldUtils.vec3_from_float_arr(point.pos)
		var rel_pos: Vector3 = abs_pos - start_pos
		path.curve.add_point(rel_pos)
	# add as parent and to editor scene
	self.editor_infr_node.add_child(path, true)
	path.owner = get_scene()
	return path
	
func spawn_road_line_3d(road_data_dict: Dictionary) -> LinePath3D:
	var start_pos: Vector3 = WorldUtils.vec3_from_float_arr(road_data_dict.points[0].pos)
	var line3d: LinePath3D = RoadMapper.line3d_from_data(road_data_dict)
	line3d.position = start_pos
	# create curve
	line3d.curve = Curve3D.new()
	for point in road_data_dict.points:
		var abs_pos = WorldUtils.vec3_from_float_arr(point.pos)
		var rel_pos: Vector3 = abs_pos - start_pos
		line3d.curve.add_point(rel_pos)
	# add as parent and to editor scene
	self.editor_infr_node.add_child(line3d, true)
	line3d.owner = get_scene()
	# set color
	var line_mat: ShaderMaterial = line3d.material
	line_mat.set("shader_parameter/line_width", .25)
	line_mat.set("shader_parameter/color", ROAD_COLOR)
	return line3d
#endregion

func get_map_name():
	var editor_map_name = EditorUtils.get_editor_map_name()
	if ! editor_map_name:
		Loggie.error("Cannot generate editor infrastructure: cannot get open editor map")
		return null
	return editor_map_name
