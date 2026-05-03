class_name VehiclePath extends Path3D

@export var tracks: Array[RailTrackData] = []

@export var vehicle3d: Train3D

@export var motor: TrainMotor:
	get(): return self.vehicle3d.motor

func rebuild_path_on_current_track():
	var nodes_til_end: Array[RailNodeData] = []
	var iterations: int = 0
	var next_segment: VehiclePathSegment = self.get_first_segment()
	while next_segment && iterations <= 30:
		nodes_til_end.append_array(next_segment.get_nodes_directionally())
		next_segment = next_segment.find_next_segment()
	# build curve from path
	self.curve = Curve3D.new()
	self.curve.up_vector_enabled = false
	for path_node in nodes_til_end:
		# TODO: we could add handle in & out here
		self.curve.add_point(path_node.position)
	InfrUtils.smooth_curve3d(self.curve)

func get_first_segment() -> VehiclePathSegment:
	var veh_parking_node: RailNodeData = self.vehicle3d.last_node
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
