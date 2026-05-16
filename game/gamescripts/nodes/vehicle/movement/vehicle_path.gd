class_name VehiclePath extends Path3D

@export var curr_segment: Array[RailTrackData] = []

@export var train3d: Train3D

@export var motor: TrainMotor:
	get(): return self.train3d.motor

func rebuild_path_on_current_track():
	# build segment list
	var nodes_til_end: Array[RailNodeData] = []
	var path_segments: Array[VehiclePathSegment] = self.get_segments_from_first(self.get_first_segment())
	# collect all rail nodes from segments
	for segment in path_segments:
		nodes_til_end.append_array(segment.get_nodes_directionally())
	# build curve from path
	self.curve = Curve3D.new()
	self.curve.up_vector_enabled = false
	for path_node in nodes_til_end:
		# TODO: we could add handle in & out here
		self.curve.add_point(path_node.position)
	InfrUtils.smooth_curve3d(self.curve)

func get_segments_from_first(first_segment: VehiclePathSegment) -> Array[VehiclePathSegment]:
	var all_segments: Array[VehiclePathSegment] = []
	var iterations: int = 0
	var current_segment: VehiclePathSegment = first_segment
	while current_segment && iterations <= 30:
		all_segments.append(current_segment)
		current_segment = VehiclePathSegmentBuilder.find_next_segment(current_segment)
	return all_segments

func get_first_segment() -> VehiclePathSegment:
	var veh_parking_node: RailNodeData = self.train3d.last_node
	var first_track_num = veh_parking_node.parent_track.num
	var motor_direction: Enums.PathDirection = self.motor.direction
	return VehiclePathSegment.of_rail(first_track_num, motor_direction)

#region Callbacks
func _enter_tree() -> void:
	SignalBus.fork_changed.connect(Callable(self, "_on_fork_changed"))

func _ready() -> void:
	self.rebuild_path_on_current_track()

func _on_fork_changed(_fork: RailNodeForkData):
	self.rebuild_path_on_current_track()
#endregion
