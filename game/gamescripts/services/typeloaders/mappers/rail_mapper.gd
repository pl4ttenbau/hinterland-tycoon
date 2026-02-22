@tool
class_name RailMapper extends RefCounted

static func rail_track_from_dict(_track_dict: Dictionary) -> RailTrackData:
	var track_instance := RailTrackData.new()
	track_instance.num = int(_track_dict.num)
	track_instance.infr_type_key = _track_dict.get("type")
	# start pos
	var start_pos_arr =  _track_dict.points[0].pos
	track_instance.start_pos = WorldUtils.vec3_from_float_arr(start_pos_arr)
	# optionals
	if _track_dict.has("name"):
		track_instance.track_name = _track_dict.get("name")
	if _track_dict.has("hideBed") &&  _track_dict.get("hideBed") == true:
		track_instance.hideFill = true
	# add path nodes
	_add_points_from_json(_track_dict, track_instance)
	return track_instance
	
static func _add_points_from_json(_json_track: Dictionary, _track: RailTrackData):
	var node_index: int = 0
	for rail_node_dict: Dictionary in _json_track.points:
		var abs_node_pos: Vector3 = WorldUtils.vec3_from_float_arr(rail_node_dict.pos)
		var rail_node := RailNodeData.of(node_index, abs_node_pos, _track)
		rail_node.rel_position = abs_node_pos - _track.start_pos
		var vec3: Vector3 = WorldUtils.vec3_from_float_arr(rail_node_dict.pos)
		var rail_node_obj := RailNodeData.of(node_index, vec3, _track)
		rail_node_obj.parse_and_add_special(rail_node_dict)
		_track.add_node(rail_node_obj, false)
		node_index += 1

#region Path3D or Line3D
static func path3d_from_data(track_data_dict: Dictionary) -> Path3D:
	var track_num: int = track_data_dict.get("num")
	var track_path := Path3D.new()
	track_path.name = "Editor_Track%d" % track_num
	# position
	track_path.position = WorldUtils.vec3_from_float_arr(track_data_dict.points[0].pos)
	# set metadata
	track_path.set_meta("track_num", track_num)
	track_path.set_meta("name", track_data_dict.get("name", null))
	track_path.debug_custom_color = Color(0, 0.01, 0)
	return track_path
	
static func editor_line_from_data(track_data_dict: Dictionary) -> EditorInfrLine3D:
	var track_num: int = track_data_dict.get("num")
	var editor_line3d := EditorInfrLine3D.of(Enums.InfrDomain.RAIL, track_num,
			track_data_dict.get("name", null))
	editor_line3d.position = WorldUtils.vec3_from_float_arr(track_data_dict.points[0].pos)
	return editor_line3d
#endregion
