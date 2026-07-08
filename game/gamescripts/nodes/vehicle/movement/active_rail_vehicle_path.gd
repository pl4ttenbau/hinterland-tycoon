class_name ActiveRailVehiclePath extends Path3D

signal extended(added_segment)

@export var initial_segment: VehiclePathSegment

static func of_segment(_segment: VehiclePathSegment) -> ActiveRailVehiclePath:
	# create instance
	var active_path: ActiveRailVehiclePath = ActiveRailVehiclePath.new()
	active_path.initial_segment = _segment
	# build curve from path
	active_path.curve = Curve3D.new()
	active_path.curve.up_vector_enabled = false
	# add segments
	active_path.add_segment(_segment)
	return active_path

func add_segment(added_segment: VehiclePathSegment) -> Curve3D:
	for path_node in added_segment.get_nodes_directionally():
		# TODO: we could add handle in & out here
		self.curve.add_point(path_node.position)
	InfrUtils.smooth_curve3d(self.curve)
	# fire extended signal & return full curve
	self.extended.emit(added_segment)
	return self.curve
