@tool
class_name RoadMapper extends RefCounted

static func road_from_data_json(_road_dict: Dictionary) -> RoadData:
	var road_num := int(_road_dict.get("num"))
	var type_key := str(_road_dict.get("type"))
	var road_instance := RoadData.of(road_num, type_key)
	if _road_dict.has("name"):
		road_instance.track_name = _road_dict.get("name")
	# start pos
	var start_pos_arr =  _road_dict.points[0].pos
	road_instance.start_pos = WorldUtils.vec3_from_float_arr(start_pos_arr)
	# road_instance.name = "RoadWay" + str(road_instance.num)
	add_points_from_json(_road_dict, road_instance)
	road_instance.created.emit(road_instance)
	return road_instance

static func add_points_from_json(_json_track: Dictionary, _road: RoadData):
	var node_index: int = 0
	for rail_node_dict: Dictionary in _json_track.points:
		var abs_node_pos: Vector3 = WorldUtils.vec3_from_float_arr(rail_node_dict.pos)
		var road_node := RoadNode.of(node_index, abs_node_pos, _road)
		road_node.rel_position = abs_node_pos - _road.start_pos
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
	# position
	road_path.position = WorldUtils.vec3_from_float_arr(road_data_dict.points[0].pos)
	# set metadata
	road_path.name = "Editor_Road%d" % road_num
	road_path.set_meta("road_num", road_num)
	road_path.set_meta("name", road_data_dict.get("name", null))
	return road_path
	
static func editor_line_from_data(road_data_dict: Dictionary) -> EditorInfrLine3D:
	var road_num: int = road_data_dict.get("num")
	var editor_line3d := EditorInfrLine3D.of(Enums.InfrDomain.ROAD, road_num,
			road_data_dict.get("name", null))
	editor_line3d.position = WorldUtils.vec3_from_float_arr(road_data_dict.points[0].pos)
	return editor_line3d
