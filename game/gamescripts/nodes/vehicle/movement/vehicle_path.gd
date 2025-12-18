class_name VehiclePath extends Path3D

@export var tracks: Array[RailTrackData] = []

@export var vehicle: RailVehicle3D

func rebuild_path_on_current_track():
	self.curve = Curve3D.new()
	var continues: bool = true
	var iterations: int = 0
	var next_track = self.vehicle.last_node.parent_track
	var next_direction = self.vehicle.direction
	while continues && iterations <= 20:
		var segment_end := self.add_track_nodes(next_track, next_direction)
		# track goes on
		if segment_end && segment_end.fork && segment_end.fork.set_to:
			var next_track_num = segment_end.fork.set_to
			next_track = RailTrackData.get_by_num(next_track_num)
			next_direction = get_next_dir_from_fork(next_track.num, segment_end.position)
		else:
			continues = false
			self.vehicle.motor.stop()
			return
		iterations += 1
	InfrUtils.smooth_curve3d(self.curve)
		
func get_next_dir_from_fork(track_num: int, fork_pos: Vector3) -> VehicleMotor.Direction:
	var track_obj: RailTrackData = RailTrackData.get_by_num(track_num)
	for rail_node: RailNodeData in track_obj.nodes:
		if rail_node.position == fork_pos:
			if rail_node.is_last(): return VehicleMotor.Direction.TRACK_NODES_DECREASE
	return VehicleMotor.Direction.TRACK_NODES_INCREASE
	
## returns last node on current track
func add_track_nodes(track: RailTrackData, dir: VehicleMotor.Direction) -> RailNodeData:
	if dir == VehicleMotor.Direction.TRACK_NODES_DECREASE:
		for i in track.nodes.size():
			var node: RailNodeData = track.nodes[-i-1]
			self.curve.add_point(node.position)
		return track.nodes[0]
	else:
		for node: RailNodeData in track.nodes:
			self.curve.add_point(node.position)
		return track.nodes[track.nodes.size() -1]
	
#region Callbacks
func _enter_tree() -> void:
	SignalBus.fork_changed.connect(Callable(self, "_on_fork_changed"))
	
func _ready() -> void:
	self.rebuild_path_on_current_track()

func _on_fork_changed(_fork: RailNodeForkData):
	self.rebuild_path_on_current_track()
#endregion
