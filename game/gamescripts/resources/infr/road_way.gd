@icon("res://assets/icons/icon_road_white.png")
@warning_ignore("missing_tool")
class_name RoadData extends AbstractTrack

const RURAL_ROAD_SCENE_PATH = "res://assets/meshes/infr/road/rural_road_1/path_rural_road_1.tscn"
const DIRT_PATH_SCENE_PATH = "res://assets/meshes/infr/road/dirt_path/path_dirt_path.tscn"

@export var autosmooth: bool = true

@export var nodes: Array[RoadNode] = []
@export_storage var crosses: Array[RoadCross] = []

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
func spawn() -> RoadWay3D:
	var definition := get_road_type()
	if definition == null:
		return null
	if ! self.curve: self.build_curve()
	var outer_road := definition.scene.instantiate() as RoadWay3D
	outer_road.road = self
	outer_road.apply_mesh_profile(definition)
	return outer_road
	
func build_curve() -> void:
	self.curve = Curve3D.new()
	self.curve.up_vector_enabled = false
	# add points to curve (optionally with curve handles)
	for node: RoadNode in self.nodes:
		self.curve.add_point(node.position, node.handle_in, node.handle_out)
	# generate AABB
	self.abs_aabb = InfrUtils.get_aabb(self.vertices)
	if self.autosmooth:
		InfrUtils.smooth_curve3d(self.curve, true)
	# Consumers must receive the finished curve, including its generated handles.
	self.curve_built.emit(self.curve)
	
func add_node(_road_node: RoadNode):
	self.nodes.append(_road_node) 
	self.vertices.append(_road_node.position)
#endregion

#region Getters
func get_road_type() -> RoadType:
	if GameTypes.road_types.is_empty() and GameTypes.ensure_initialized() != OK:
		return null
	return GameTypes.get_road_type(self.infr_type_key)

func get_type_scene() -> String:
	var definition := get_road_type()
	return definition.scene.resource_path if definition != null else ""

#endregion

#region Helper-Methods
func _to_string() -> String:
	return "RoadWay_%d" % self.num
	
static func get_by_num(road_num: int) -> RoadData:
	return Managers.roads.storage.get_by_num(road_num)
#endregion
