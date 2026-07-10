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
	if SHOW_DEBUG:
		self.add_debug_markers(added_segment)
	# fire extended signal & return full curve
	self.extended.emit(added_segment)
	return self.curve
#endregion

#region Reversing
func build_curve_from_pos_to_track_end() -> Curve3D:
	var curr_segment: VehiclePathSegment = self.segments[self.segments.size() -1]
	# first passed Node if the current rail track
	var new_curve: Curve3D = Curve3D.new()
	new_curve.up_vector_enabled = false
	# add points: current train pos and start of current segment
	var curr_locomotive_pos: Vector3 = self.train3d.locomotive.global_position
	new_curve.add_point(curr_locomotive_pos)
	Loggie.info("Node Added: current %v" % curr_locomotive_pos)
	var segment_start: Vector3 = curr_segment.start_node.position
	new_curve.add_point(segment_start)
	Loggie.info("Node Added: current %v" % segment_start)
	# revert segment order
	curr_segment.reverse()
	self.segments = [curr_segment]
	# return new Curve3D
	return new_curve

func get_closest_passed_rail_node_index() -> int:
	var closest_rail_node_i: int = -1
	var closest_node_dist: float = -1
	for point_i: int in range(self.curve.point_count):
		var point_pos: Vector3 = self.curve.get_point_position(point_i)
		var point_dist: float = point_pos.distance_squared_to(self.train3d.global_position)
		if point_dist > closest_node_dist:
			closest_rail_node_i = point_i
			closest_node_dist = point_dist
	return closest_rail_node_i 
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
