class_name VehiclePath extends Path3D

@export var tracks: Array[RailTrackData] = []

@export var vehicle: RailVehicle
	
func _init(_vehicle: RailVehicle):
	self.vehicle = _vehicle
	self.curve = Curve3D.new()

func rebuild_path_on_current_track():
	var continues: bool = true
	var iterations: int = 0
	while continues && iterations <= 20:
		var track = self.vehicle.last_node.parent_track
		var track_end := self.add_track_nodes(track, self.vehicle.direction)
		if track_end && track_end.fork && track_end.fork.set_to:
			var next_track_num = track_end.fork.set_to
			track = RailTrackData.get_by_num(next_track_num)
		else:
			continues = false
			return
		iterations += 1
	
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

func _on_fork_changed(fork: RailForkData):
	self.rebuild_path_on_current_track()
#endregion
