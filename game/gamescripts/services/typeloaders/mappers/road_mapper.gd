@tool
class_name RoadMapper extends RefCounted

static func road_from_data_json(_road_dict: Dictionary) -> RoadData:
	var road_num := int(_road_dict.get("num"))
	var type_key := str(_road_dict.get("type"))
	var road_instance := RoadData.of(road_num, type_key)
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
			var road_cross := cross_from_dict_and_data(road_node, rail_node_dict.get("cross"))
			# and add to road cross list
			_road.crosses.append(road_cross)
		_road.add_node(road_node)
		node_index += 1

static func cross_from_dict_and_data(parent_node: RoadNode, road_data: Dictionary) -> RoadCross:
	var road_cross: RoadCross = RoadCross.of(parent_node, [])
	road_cross.parent_node = parent_node
	# add connective roads
	var connective_roads: Array = road_data.get("connectiveRoads", null)
	if connective_roads:
		for conn_road_float: float in connective_roads:
			road_cross.connecting_roads.append(int(conn_road_float))
	return road_cross

static func path3d_from_data(road_data_dict: Dictionary) -> Path3D:
	var road_num: int = road_data_dict.get("num")
	var road_path := Path3D.new()
	road_path.name = "Editor_Road%d" % road_num
	road_path.set_meta("road_num", road_num)
	road_path.set_meta("name", road_data_dict.get("name", null))
	return road_path
