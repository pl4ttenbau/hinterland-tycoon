class_name RailVehicle extends Node3D

const scene_path = "res://scenes/subscenes/rail_vehicle.tscn"

@export var path_to_next_node: Path3D
@export var used_section: UsedRailSection = UsedRailSection.new()
@export var starting_track: RailTrackContainer
@export var motor: VehicleMotor

signal reached_next_node(int)

static func of(_starting_track: RailTrackContainer, _starts_at: int) -> RailVehicle:
	var scene: PackedScene = load(scene_path)
	var instance: RailVehicle = scene.instantiate()
	instance.used_section.track = _starting_track
	instance.motor = VehicleMotor.of(instance)
	# add start & target track node
	instance.set_next_section(_starts_at)
	return instance
	
func set_next_section(_next_point_index: int):
	self.set_origin_point(_next_point_index)
	self.set_target_point(_next_point_index +1)
	
func set_origin_point(_point_index: int):
	self.position = self.get_pos_in_track(_point_index)
	self.used_section.origin = get_node_in_track(_point_index)
	
func set_target_point(_point_index: int):
	var next_node_pos = self.get_pos_in_track(_point_index)
	self.used_section.target = get_node_in_track(_point_index)
	# look towards new target
	self.look_at_from_position(self.position, next_node_pos)
	
func update_next_point():
	self.set_next_section(self.used_section.target.index)
	
func _physics_process(delta: float) -> void:
	# get_global_transform().basis.z.normalized()
	var target_rail_node: RailNode = self.used_section.target
	translate(Vector3(0, 0, -.03))
	if (position.distance_to(target_rail_node.position) <= 1):
		print("Vehicle: Next node reached!")
		reached_next_node.emit(target_rail_node.index)
		update_next_point()
			
func get_static_body() -> StaticBody3D:
	return self.get_child(0)
	
func get_node_in_track(_index: int) -> RailNode:
	var track: RailTrack = self.used_section.track.rail_track
	return track.get_rail_node(_index)

func get_current_track() -> RailTrack:
	return self.used_section.track.rail_track	

func get_pos_in_track(_index: int) -> Vector3:
	var track_path: Path3D = self.used_section.track.get_path_3d()
	return track_path.curve.get_point_position(_index)
