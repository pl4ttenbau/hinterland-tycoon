@tool
class_name RailMapper extends RefCounted

static func rail_track_from_dict(_track_dict: Dictionary) -> RailTrackData:
	var track_instance := RailTrackData.new()
	track_instance.num = int(_track_dict.num)
	track_instance.infr_type_key = _track_dict.get("type")
	track_instance.offset = WorldUtils.vec3_from_float_arr(_track_dict.offset)
	if _track_dict.has("name"):
		track_instance.track_name = _track_dict.get("name")
	if _track_dict.has("startsNorthWest"):
		track_instance.starts_northwest = _track_dict.get("startsNorthWest")
	_add_points_from_json(_track_dict, track_instance)
	track_instance.created.emit(track_instance)
	return track_instance
	
static func _add_points_from_json(_json_track: Dictionary, _track: RailTrackData):
	var node_index: int = 0
	for rail_node_dict: Dictionary in _json_track.points:
		var vec3: Vector3 = WorldUtils.vec3_from_float_arr(rail_node_dict.pos)
		var rail_node_obj := RailNodeData.of(node_index, vec3, _track)
		rail_node_obj.parse_and_add_special(rail_node_dict)
		_track.add_node(rail_node_obj)
		node_index += 1
