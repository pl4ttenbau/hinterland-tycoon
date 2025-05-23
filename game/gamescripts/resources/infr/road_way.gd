class_name RoadWay extends AbstractTrack

const SCENE_PATH = "res://scenes/subscenes/infr/road_path_mesh_3d.tscn"

@export var nodes: Array[RoadNode] = []
@export_storage var crosses: Array[RoadCross] = []

signal created(track: RailTrack)

func _init(_num: int, _type: String):
	self.num = _num
	self.infr_type_key = _type
	
func _to_string() -> String:
	return "RoadWay_%d" % self.num

func spawn() -> OuterRoad:
	if ! self.curve: self.build_path()
	# instanciate Container from PackedScene
	var scene: Resource = preload(SCENE_PATH)
	var _container: OuterRoad = scene.instantiate() as OuterRoad
	_container.set_road(self)
	add_to_group("Roads")
	return _container

static func from_json(_road_dict: Dictionary) -> RoadWay:
	var road_num := int(_road_dict.get("num"))
	var type_key := str(_road_dict.get("type"))
	var road_instance: RoadWay = RoadWay.new(road_num, type_key)
	road_instance.position = WorldUtils.vec3_from_float_arr(_road_dict.offset)
	road_instance.name = "RoadWay" + str(road_instance.num)
	add_points_from_json(_road_dict, road_instance)
	road_instance.created.emit(road_instance)
	return road_instance

static func add_points_from_json(_json_track: Dictionary, _road: RoadWay):
	var node_index: int = 0
	for rail_node_dict: Dictionary in _json_track.points:
		var vec3: Vector3 = WorldUtils.vec3_from_float_arr(rail_node_dict.pos)
		var road_node: RoadNode = RoadNode.of(node_index, vec3, _road)
		if rail_node_dict.has("cross"):
			# var connective_roads = rail_node_dict.get("connectiveRoads", null) as Array[int]
			var cross: RoadCross = RoadCross.new(road_node, [])
			_road.crosses.append(cross)
			road_node.set_meta("cross", cross)
		_road.add_node(road_node)
		node_index += 1

func add_node(_road_node: RoadNode):
	self.nodes.append(_road_node) 
	self.vertices.append(_road_node.position)
	
func get_road_node(_i: int) -> RoadNode:
	if _i > 0:
		return self.nodes.get(_i)
	return null
