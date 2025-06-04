class_name RailVehicle extends VisibleObject

const scene_path = "res://scenes/subscenes/rail_vehicle.tscn"

@export var vehicle_num: int
@export var path_to_next_node: Path3D
@export var starting_track: OuterRailTrack
@export var rail_section: TrackSection

@export var motor: VehicleMotor

signal reached_next_node(int)

static func of(_starting_track: OuterRailTrack, _starts_at: int) -> RailVehicle:
	var scene: PackedScene = load(scene_path)
	var instance: RailVehicle = scene.instantiate()
	# put on tracks
	instance.starting_track = _starting_track
	instance.motor = VehicleMotor.of(instance)
	instance._initialize_starting_section(_starts_at)
	return instance
	
func _initialize_starting_section(_start_node_index: int) -> void:
	# add start & target track node
	self.rail_section = TrackSection.new()
	self.set_origin_point(_start_node_index)
	self.set_target_point(_start_node_index +1)
	
func set_origin_point(_point_index: int):
	var last_node: RailNode = self.get_node_in_track(_point_index)
	self.rail_section.set_last(last_node)
	# self.rail_section.last_node = 
	self.position = self.get_point_in_curve(_point_index)
	
func set_target_point(_point_index: int):
	var next_point: Vector3 = self.get_point_in_curve(_point_index)
	var next_node: RailNode = self.get_node_in_track(_point_index)
	self.rail_section.set_next(next_node)
	self.look_at_from_position(self.position, next_point)
	
func update_next_point():
	var new_origin_index: int = self.get_next_node_index()
	set_origin_point(new_origin_index)
	set_target_point(new_origin_index +1)
	
func _physics_process(delta: float) -> void:
	if !self.motor.is_started: return
	var forward_vec: Vector3 = Vector3(0, 0, -7 * delta)
	translate(forward_vec)
	if (position.distance_to(self.get_next_node_pos()) <= 1):
		Loggie.info("Vehicle: Next node reached!")
		var next_node: RailNode = self.rail_section.next_node
		if next_node:
			reached_next_node.emit(self.rail_section.next_node.index)
			update_next_point()
		else:
			self.motor.stop()
			
# == NODE GETTERS ==
func get_static_body() -> StaticBody3D:
	return self.get_child(0)
	
func get_curve() -> Curve3D:
	return self.starting_track.get_path_3d().curve
	
func get_point_in_curve(i: int) -> Vector3:
	if i >= get_curve().point_count:
		return Vector3.ZERO
	return self.starting_track.get_path_3d().curve.get_point_position(i)
	
func get_node_in_track(i: int) -> RailNode:
	return self.starting_track.entity.get_rail_node(i)
	
func get_last_node_pos() -> Vector3:
	if self.rail_section && self.rail_section.last_node:
		return self.rail_section.last_node.position
	return Vector3.ZERO
	
func get_next_node_pos() -> Vector3:
	if self.rail_section.next_node:
		return self.rail_section.next_node.position
	else:
		self.motor.stop()
		return self.get_last_node_pos()
	
func get_next_node_index() -> int:
	return self.rail_section.next_node.index
