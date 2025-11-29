@icon("res://assets/icons/icon_road_white.png")
@warning_ignore("missing_tool")
class_name RoadData extends AbstractTrack

const RURAL_ROAD_SCENE_PATH = "res://assets/meshes/infr/road/rural_road_1/path_rural_road_1.tscn"
const DIRT_PATH_SCENE_PATH = "res://assets/meshes/infr/road/dirt_path/path_dirt_path.tscn"

@export var nodes: Array[RoadNode] = []
@export_storage var crosses: Array[RoadCross] = []

@warning_ignore("unused_signal")
signal created(track: RoadData)

#region Initialization
func _init():
	super(Enums.EntityTypes.ROAD)
	
static func of(_num: int, _type: String) -> RoadData:
	var inst := RoadData.new()
	inst.num = _num
	inst.infr_type_key = _type
	return inst
#endregion

#region Creation
func spawn() -> OuterRoad:
	if ! self.curve: self.build_curve()
	# instanciate Container from PackedScene
	var scene: Resource = load(self.get_type_scene())
	var outer_road: OuterRoad = scene.instantiate() as OuterRoad
	outer_road.road = self
	# add_to_group("Roads")
	return outer_road
	
func build_curve() -> void:
	# if self.curve: return
	self.curve = Curve3D.new()
	self.curve.up_vector_enabled = true
	for road_node: RoadNode in self.nodes:
		self.curve.add_point(road_node.rel_position)
	
func add_node(_road_node: RoadNode):
	self.nodes.append(_road_node) 
	self.vertices.append(_road_node.position)
#endregion

#region Getters
func get_type_scene() -> String:
	if self.infr_type_key == "rural_road": return RURAL_ROAD_SCENE_PATH
	elif self.infr_type_key == "dirt_path": return DIRT_PATH_SCENE_PATH
	return RURAL_ROAD_SCENE_PATH
	
func get_road_node(_i: int) -> RoadNode:
	if _i > 0:
		return self.nodes.get(_i)
	return null
#endregion

#region Helper-Methods
func _to_string() -> String:
	return "RoadWay_%d" % self.num
	
static func get_by_num(road_num: int) -> RoadData:
	return Managers.roads.storage.get_by_num(road_num)
#endregion
