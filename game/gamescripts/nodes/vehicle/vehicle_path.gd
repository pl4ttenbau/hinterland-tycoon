class_name VehiclePath extends Path3D

@export var tracks: Array[RailTrackData] = []

@export var vehicle: RailVehicle

func rebuild_path_on_current_track():
	self.curve = Curve3D.new()
	var continues: bool = true
	var iterations: int = 0
	var next_track = self.vehicle.last_node.parent_track
	var next_direction = self.vehicle.direction
	while continues && iterations <= 20:
		var track_end := self.add_track_nodes(next_track, next_direction)
		if track_end && track_end.fork && track_end.fork.set_to:
			var next_track_num = track_end.fork.set_to
			next_track = RailTrackData.get_by_num(next_track_num)
			next_direction = get_next_dir_from_fork(next_track.num, track_end.position)
		else:
			continues = false
			self.vehicle.motor.stop()
			return
		iterations += 1
		
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
	# self.vehicle = self.get_parent_node_3d()
	SignalBus.fork_changed.connect(Callable(self, "_on_fork_changed"))
	
func _ready() -> void:
	self.rebuild_path_on_current_track()

func _on_fork_changed(fork: RailForkData):
	self.rebuild_path_on_current_track()
#endregion
