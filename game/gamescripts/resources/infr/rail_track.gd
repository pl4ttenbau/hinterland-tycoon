@icon("res://assets/icons/icon_rail_track_white.png")
@warning_ignore("missing_tool")
class_name RailTrackData extends AbstractTrack

@export var nodes: Array[RailNodeData] = []
@export var hideFill: bool = false

## Travel direction into the junction from the approach track, for runtime builds.
@export_storage var start_tangent: Vector3

# child objects
@export var forks: Array[RailJunctionArm] = []

const NEAR_DISTANCE_MAX: float = 100.0

func _init():
	super(Enums.EntityTypes.RAIL)

static func get_by_num(_rail_num: int) -> RailTrackData:
	return Managers.rails.track_storage.get_by_num(_rail_num)

## Gauge definition from the rail type catalog; null when the catalog cannot load.
func get_rail_type() -> RailType:
	if GameTypes.rail_types.is_empty() and GameTypes.ensure_initialized() != OK:
		return null
	return GameTypes.get_rail_type(self.infr_type_key)

## Distance from the track curve to the top of the rail, in metres.
func get_rail_head_height() -> float:
	var definition: RailType = self.get_rail_type()
	return definition.rail_head_height_metres if definition != null else 0.0

func get_gauge_mm() -> int:
	var definition: RailType = self.get_rail_type()
	return definition.gauge_mm if definition != null else 0
	
#region Nodes & Forks
func get_nodes() -> Array:
	return self.nodes

func add_fork(rail_fork: RailJunctionArm):
	self.forks.append(rail_fork)
#endregion

#region Curve
func _curve_up_vector_enabled() -> bool:
	return true

## A track built off a junction leaves it along the approach direction.
func _adjust_curve_handles(built: Curve3D) -> void:
	if built.point_count >= 2 and not self.start_tangent.is_zero_approx():
		var first_span: float = self.nodes[0].position.distance_to(self.nodes[1].position)
		built.set_point_out(0, self.start_tangent * (first_span / 3.0))
#endregion

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
## Typed shortcuts for rail callers.
func get_rail_node(_i: int) -> RailNodeData:
	return self.get_node_at(_i)
	
func get_end_node() -> RailNodeData:
	return self.last_node()

func get_node_forks() -> Array[RailJunctionArm]:
	var node_forks: Array[RailJunctionArm] = []
	if self.nodes[0].fork:
		node_forks.append(self.nodes[0].fork)
	if self.get_end_node().fork:
		node_forks.append(self.get_end_node().fork)
	return node_forks
#endregion

func _to_string() -> String:
	return "RailTrack_%d" % self.num
