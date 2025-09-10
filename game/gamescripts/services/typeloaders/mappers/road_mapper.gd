@tool
class_name RoadMapper extends RefCounted

static func road_from_data_json(_road_dict: Dictionary) -> RoadData:
	var road_num := int(_road_dict.get("num"))
	var type_key := str(_road_dict.get("type"))
	var road_instance := RoadData.new(road_num, type_key)
	if _road_dict.has("name"):
		road_instance.track_name = _road_dict.get("name")
	if _road_dict.has("offset"):
		road_instance.offset = WorldUtils.vec3_from_float_arr(_road_dict.offset)
	# road_instance.name = "RoadWay" + str(road_instance.num)
	add_points_from_json(_road_dict, road_instance)
	road_instance.created.emit(road_instance)
	return road_instance

static func add_points_from_json(_json_track: Dictionary, _road: RoadData):
	var node_index: int = 0
	for rail_node_dict: Dictionary in _json_track.points:
		var vec3: Vector3 = WorldUtils.vec3_from_float_arr(rail_node_dict.pos)
		var road_node := RoadNode.of(node_index, vec3, _road)
		if rail_node_dict.has("cross"):
			# var connective_roads = rail_node_dict.get("connectiveRoads", null) as Array[int]
			var cross: RoadCross = RoadCross.new(road_node, [])
			_road.crosses.append(cross)
			road_node.set_meta("cross", cross)
		_road.add_node(road_node)
		node_index += 1
