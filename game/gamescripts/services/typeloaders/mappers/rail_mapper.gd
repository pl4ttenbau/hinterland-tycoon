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
	if _track_dict.has("hideBed"):
		track_instance.hideFill = _track_dict.get("hideBed")
	if _track_dict.has("tag"):
		track_instance.tag = _track_dict.get("tag")
	# add path nodes
	_add_points_from_json(_track_dict, track_instance)
	return track_instance
	
static func _add_points_from_json(_json_track: Dictionary, _track: RailTrackData):
	var node_index: int = 0
	for rail_node_dict: Dictionary in _json_track.points:
		var abs_pos_vec3: Vector3 = WorldUtils.vec3_from_float_arr(rail_node_dict.pos)
		var rail_node_obj := RailNodeData.of(node_index, abs_pos_vec3, _track)
		rail_node_obj.rel_position = abs_pos_vec3 - _track.start_pos
		rail_node_obj.parse_and_add_special(rail_node_dict)
		_track.add_node(rail_node_obj, false)
		node_index += 1

#region Path3D or Line3D
static func editor_line_from_data(track_data_dict: Dictionary) -> EditorInfrLine3D:
	var track_num: int = track_data_dict.get("num")
	var editor_line3d := EditorInfrLine3D.ofRail(track_num, track_data_dict.get("name", null))
	editor_line3d.position = WorldUtils.vec3_from_float_arr(track_data_dict.points[0].pos)
	return editor_line3d
#endregion
