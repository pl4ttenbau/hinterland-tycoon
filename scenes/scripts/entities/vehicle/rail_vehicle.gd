class_name RailVehicle extends Node3D


const scene_path = "res://scenes/subscenes/rail_vehicle.tscn"

@export var path_to_next_node: Path3D

@export var starting_track: RailTrackContainer
@export var last_point: Vector3
@export var last_point_index: int
@export var next_point: Vector3
@export var next_point_index: int

@export var motor: VehicleMotor

signal reached_next_node(int)

static func of(_starting_track: RailTrackContainer, _starts_at: int) -> RailVehicle:
	var scene: PackedScene = load(scene_path)
	var instance: RailVehicle = scene.instantiate()
	instance.starting_track = _starting_track
	instance.motor = VehicleMotor.of(instance)
	# add start & target track node
	instance.set_origin_point(_starts_at)
	instance.set_target_point(_starts_at +1)
	return instance
	
func set_origin_point(_point_index: int):
	self.last_point_index = _point_index
	self.last_point = self.get_point_in_curve(_point_index)
	self.position = self.last_point
	# create path to next point (without target vec yet)
	# self.path_to_next_node = Path3D.new()
	# self.path_to_next_node.position = self.position
	# self.path_to_next
	
func set_target_point(_point_index: int):
	self.next_point_index = _point_index
	self.next_point = self.get_point_in_curve(_point_index)
	self.look_at_from_position(self.position, self.next_point)
	
func update_next_point():
	var new_origin_index: int = self.next_point_index
	set_origin_point(new_origin_index)
	set_target_point(new_origin_index +1)
	
func _process(delta: float) -> void:
	# get_global_transform().basis.z.normalized()
	translate(Vector3(0, 0, -.03))
	if (position.distance_to(self.next_point) <= 1):
		print("Vehicle: Next node reached!")
		reached_next_node.emit(self.next_point_index)
		update_next_point()
			
func get_static_body() -> StaticBody3D:
	return self.get_child(0)
	
func get_point_in_curve(i: int) -> Vector3:
	return self.starting_track.get_path_3d().curve.get_point_position(i)
