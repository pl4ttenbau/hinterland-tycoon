class_name ActiveRailVehiclePath extends Path3D

@export var initial_segment: VehiclePathSegment

static func of_segment(_segment: VehiclePathSegment) -> ActiveRailVehiclePath:
	# create instance
	var path: ActiveRailVehiclePath = ActiveRailVehiclePath.new()
	path.initial_segment = _segment
	# collect nodes
	var nodes: Array[RailNodeData] = _segment.get_nodes_directionally()
	# build curve from path
	path.curve = Curve3D.new()
	path.curve.up_vector_enabled = false
	for path_node in nodes:
		# TODO: we could add handle in & out here
		path.curve.add_point(path_node.position)
	InfrUtils.smooth_curve3d(path.curve)
	return path
