@icon("res://assets/icons/icon_rail_track_white.png")
@warning_ignore("missing_tool")
class_name RailTrackData extends AbstractTrack

@export var nodes: Array[RailNodeData] = []
@export var hideFill: bool = false

## Travel direction into the junction from the approach track, for runtime builds.
@export_storage var start_tangent: Vector3

# child objects
@export var node_stations: Array[NodeStationLinkData] = []
@export var forks: Array[RailNodeForkData] = []

const NEAR_DISTANCE_MAX: float = 100.0
## Distance from the track curve to the top of the rail mesh, in metres.
const RAIL_HEAD_HEIGHT_METRES: Dictionary[String, float] = {
	"NORMAL_GAUGE": 0.262066,
	InfrType.GAUGE_1000_MM: 0.262066,
	"750_MM": 0.262066,
	"600_MM": 0.262066,
}

func _init():
	super(Enums.EntityTypes.RAIL)

static func get_by_num(_rail_num: int) -> RailTrackData:
	return Managers.rails.track_storage.get_by_num(_rail_num)

func get_rail_head_height() -> float:
	# Legacy track types use the standard-gauge scene.
	return RAIL_HEAD_HEIGHT_METRES.get(self.infr_type_key, RAIL_HEAD_HEIGHT_METRES["NORMAL_GAUGE"])

func get_gauge_mm() -> int:
	if self.infr_type_key == InfrType.GAUGE_1000_MM:
		return 1000
	if self.infr_type_key == "750_MM":
		return 750
	if self.infr_type_key == "600_MM":
		return 600
	return 1435
	
#region Add Nodes
func add_node(rail_node: RailNodeData, update: bool):
	self.nodes.append(rail_node) 
	self.vertices.append(rail_node.position)
	if update:
		self.build_curve()
		self.track_changed.emit()
	
func add_fork(rail_fork: RailNodeForkData):
	self.forks.append(rail_fork)
#endregion

func build_curve() -> void:
	self.curve = Curve3D.new()
	self.curve.up_vector_enabled = true
	# add points to curve (optionally with curve handles)
	for node: RailNodeData in self.nodes:
		self.curve.add_point(node.position, node.handle_in, node.handle_out)
	if self.curve.point_count >= 2 and not self.start_tangent.is_zero_approx():
		var first_span: float = self.vertices[0].distance_to(self.vertices[1])
		self.curve.set_point_out(0, self.start_tangent * (first_span / 3.0))
	self.abs_aabb = InfrUtils.get_aabb(self.vertices)
	InfrUtils.smooth_curve3d(self.curve, true)
	self.curve_built.emit(self.curve)

## The endpoint handle points into the track. Negate it for travel into the junction.
func get_tangent_into_endpoint(node: RailNodeData) -> Vector3:
	if self.curve == null:
		self.build_curve()
	var handle: Vector3 = self.curve.get_point_out(node.index) if node.is_first() else self.curve.get_point_in(node.index)
	if not handle.is_zero_approx():
		return -handle.normalized()
	if self.curve.point_count < 2:
		return Vector3.ZERO
	var adjacent: int = 1 if node.is_first() else node.index - 1
	var adjacent_handle: Vector3 = self.curve.get_point_in(adjacent) if node.is_first() else self.curve.get_point_out(adjacent)
	var adjacent_pos: Vector3 = self.curve.get_point_position(adjacent)
	var tangent: Vector3 = node.position - adjacent_pos - adjacent_handle
	return tangent.normalized() if not tangent.is_zero_approx() else adjacent_pos.direction_to(node.position)

#region Distance Check
func is_near(pos: Vector3) -> bool:
	if self.get_start_pos().distance_to(pos) <= NEAR_DISTANCE_MAX:
		return true
	elif self._get_center().distance_to(pos) <= NEAR_DISTANCE_MAX:
		return true
	elif self.get_end_pos().distance_to(pos) <= NEAR_DISTANCE_MAX:
		return true
	return false
#endregion

#region Get Nodes
func get_rail_node(_i: int) -> RailNodeData:
	if _i >= 0 && _i < self.nodes.size():
		return self.nodes.get(_i)
	return null
	
func get_end_node() -> RailNodeData:
	var last_i: int = self.nodes.size() -1
	return self.nodes[last_i]

func has_node_index(_index: int) -> bool:
	var last_i: int = self.nodes.size() -1
	return _index >= 0 && _index <= last_i

func get_node_forks() -> Array[RailNodeForkData]:
	var node_forks: Array[RailNodeForkData] = []
	if self.nodes[0].fork:
		node_forks.append(self.nodes[0].fork)
	if self.get_end_node().fork:
		node_forks.append(self.get_end_node().fork)
	return node_forks
#endregion

func _to_string() -> String:
	return "RailTrack_%d" % self.num
