class_name VehicleWheels extends Resource

@export_storage var vehicle: RailVehicle
@export var current_node_i: int
@export var current_track: RailTrackData
@export var current_section: TrackSectionData

@export_storage var target: RailNodeData:
	get: return self.current_section.target

func _init(_vehicle: RailVehicle, _track: RailTrackData, _start_index: int):
	self.vehicle = _vehicle
	self.current_track = _track
	self.current_node_i = _start_index
	# create section
	self.current_section = TrackSectionData.new()
	self.current_section.track = _track
	self.current_section.origin = _track.get_rail_node(_start_index)

func set_origin_point(_point_index: int):
	var start_node: RailNodeData = self.get_node_obj(_point_index)
	self.current_section.origin = start_node
	self.current_node_i = _point_index
	# self.rail_section.last_node = 
	self.vehicle.position = self.get_node_pos(_point_index)
	
func set_target_point(_point_index: int):
	var target_node: RailNodeData = self.get_node_obj(_point_index)
	self.current_section.target = target_node
	if target_node:
		self.vehicle.rotate_to(target_node.position)

## triggered after the vehicle hit a rail fork
func put_on_connected_track(fork_node: RailNodeData):
	if fork_node.fork && fork_node.fork.set_to:
		Loggie.info("Switching to track with num %d" % fork_node.fork.set_to)
		self.current_track = RailTrackData.get_by_num(fork_node.fork.set_to)
		self.current_node_i = 0
		if self.vehicle.direction == VehicleMotor.Direction.TRACK_NODES_DECREASE:
			self.current_node_i = current_track.get_end_node().index
		self.put_on_track()
		self.vehicle.motor.start()

func put_on_track() -> void:
	self.set_origin_point(self.current_node_i)
	var next_i = self.current_node_i +1
	if self.vehicle.direction == VehicleMotor.Direction.TRACK_NODES_DECREASE:
		next_i = self.current_node_i -1
	self.set_target_point(next_i)

#region Getters
func get_node_obj(_i: int) -> RailNodeData:
	return self.current_track.get_rail_node(_i)
	
func get_node_pos(_i: int) -> Vector3:
	return self.current_track.vertices[_i]
#endregion
