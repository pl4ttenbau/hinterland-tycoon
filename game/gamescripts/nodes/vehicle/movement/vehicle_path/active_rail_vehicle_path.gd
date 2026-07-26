class_name ActiveRailVehiclePath extends Path3D

const SHOW_DEBUG: bool = true
const SEGMENT_NODE_MARKER_PATH = "res://assets/meshes/markers/infr_end/selected_node.tscn"
const DEBUG_MARKERS_PARENT_NAME = "DebugMarkers"

signal extended(added_segment)

@export var train3d: Train3D

@export var segments: Array[VehiclePathSegment] = []

#region Initialization
static func of_segment(_train: Train3D, _segment: VehiclePathSegment) -> ActiveRailVehiclePath:
	# create instance
	var active_path: ActiveRailVehiclePath = ActiveRailVehiclePath.new()
	active_path.train3d = _train
	# build curve from path
	active_path.curve = Curve3D.new()
	active_path.curve.up_vector_enabled = false
	# add segments
	active_path.add_segment(_segment)
	return active_path
#endregion

#region Segments
func add_segment(added_segment: VehiclePathSegment) -> Curve3D:
	self.segments.append(added_segment)
	for path_node in added_segment.get_nodes_directionally():
		# TODO: we could add handle in & out here
		self.curve.add_point(path_node.position)
	InfrUtils.smooth_curve3d(self.curve)
	# show markers in debug mode
	if SHOW_DEBUG: self.add_debug_markers(added_segment)
	# fire extended signal & return full curve
	self.extended.emit(added_segment)
	return self.curve

func get_current_segment() -> VehiclePathSegment:
	if self.segments == null || self.segments.size() <= 0:
		Loggie.error("Cannot return current segment; Segment list is empty")
		return null
	return self.segments[self.segments.size() -1]
#endregion

#region Reversing
func build_curve_from_pos_to_track_end() -> Curve3D:
	var curr_segment: VehiclePathSegment = self.get_current_segment()
	# get closest passed rail node
	var segment_start_node_i: int = self.get_curve_i_from_segment_start_to_closest_node(curr_segment)[0]
	var closest_node_i: int = self.get_curve_i_from_segment_start_to_closest_node(curr_segment)[1]
	# re-create empty curve
	var curve_to_train_pos = self.get_curve_part_between_points(self.curve, segment_start_node_i, closest_node_i)
	var curve_to_segment_start = PathCurveUtils.reverse_curve3d(curve_to_train_pos)
	# revert segment order & remove all segments but current one
	curr_segment.reverse()
	self.segments = [curr_segment]
	# return new Curve3D
	return curve_to_segment_start
#endregion

#region Get Last Passed Node
func get_closest_passed_rail_node() -> RailNodeData:
	var closest_rail_node: RailNodeData = null
	var closest_node_dist: float = 9999
	for segment_node: RailNodeData in self.get_current_segment().as_rail_track().nodes:
		var point_pos: Vector3 = segment_node.position
		var point_dist: float = point_pos.distance_squared_to(self.train3d.locomotive.global_position)
		if point_dist < closest_node_dist:
			closest_rail_node = segment_node
			closest_node_dist = point_dist
	return closest_rail_node

## returns indexes of points on this path's full Curve3D
## between start of the current segment to closest RailNode of train locomotive position
func get_curve_i_from_segment_start_to_closest_node(curr_segment: VehiclePathSegment) -> Array[int]:
	# get closest passed rail node
	var last_passed_node: RailNodeData = self.get_closest_passed_rail_node()
	var last_passed_node_curve_i: int = self.get_rail_node_i_in_full_curve(last_passed_node)
	# get node at start of current segment
	var segment_start_node: RailNodeData = curr_segment.start_node
	var segment_start_node_i: int = self.get_rail_node_i_in_full_curve(segment_start_node)
	return [segment_start_node_i, last_passed_node_curve_i]

func get_curve_part_between_points(curve3d: Curve3D, start_index: int, end_index: int) -> Curve3D:
	var cut_curve: Curve3D = Curve3D.new()
	cut_curve.up_vector_enabled = curve3d.up_vector_enabled
	for curve_i: int in range(curve3d.point_count):
		if curve_i >= start_index && curve_i <= end_index:
			cut_curve.add_point(curve.get_point_position(curve_i))
	return cut_curve

## if a RailNode is part of this ActiveVehiclePath, returns index of said RailNode in path's curve
## if not, returns -1 and shows a warning
func get_rail_node_i_in_full_curve(rail_node: RailNodeData) -> int:
	for curve_i: int in range(self.curve.point_count):
		var node_pos: Vector3 = curve.get_point_position(curve_i)
		if node_pos.is_equal_approx(rail_node.position):
			return curve_i
	Loggie.warn("Cannot find RailNode(track %d, index %d) in own curve" % [rail_node.parent_track.num, rail_node.index])
	return -1

func get_transf_at_m_passed(m_passed: float) -> Transform3D:
	var target_transf := self.curve.sample_baked_with_rotation(m_passed, true)
	# only turn vertically
	target_transf = target_transf.rotated_local(Vector3(1, 0, 0), 0)
	target_transf = target_transf.rotated_local(Vector3(0, 0, 1), 0)
	return target_transf
#endregion

#region Debug Markers
func add_debug_markers(segment: VehiclePathSegment):
	# add marker at every rail node
	for rail_node: RailNodeData in segment.get_nodes_directionally():
		self._add_debug_marker_at(rail_node.position)

func _add_debug_marker_at(pos: Vector3) -> Node3D:
	var marker_prefab: PackedScene = load(SEGMENT_NODE_MARKER_PATH)
	# check for DebugPath parent, add if null
	var markers_parent: Node3D = self.get_or_add_markers_parent()
	# instantiate
	var marker_instance: Node3D = marker_prefab.instantiate()
	markers_parent.add_child(marker_instance)
	marker_instance.position = pos
	marker_instance.position.y += .8
	return marker_instance

func get_or_add_markers_parent() -> Node3D:
	if !self.has_node(DEBUG_MARKERS_PARENT_NAME):
		var new_markers_parent: Node3D = Node3D.new()
		self.add_child(new_markers_parent)
		new_markers_parent.name = DEBUG_MARKERS_PARENT_NAME
		return new_markers_parent
	else:
		return self.get_node(DEBUG_MARKERS_PARENT_NAME)
#endregion
