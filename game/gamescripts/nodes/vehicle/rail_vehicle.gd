@icon("res://assets/icons/icon_locomotive.png")
class_name RailVehicle extends VisibleObject

const SCENE_PATH = "res://assets/meshes/vehicles/loco_faur/vehicle_loco_faur.tscn"

@export var vehicle_num: int
@export var wheels: VehicleWheels
@export var motor: VehicleMotor

signal reached_next_node(int)

func _enter_tree() -> void:
	SignalBus.scene_root_ready.connect(Callable(self, "_on_world_ready"))

static func of(_starting_track: OuterRailTrack, _starts_at: int) -> RailVehicle:
	var rail_num: int = _starting_track.entity.num
	var vehicle: RailVehicle = load(SCENE_PATH).instantiate()
	vehicle.wheels = VehicleWheels.new(vehicle, _starting_track.entity, _starts_at)
	# put on tracks
	vehicle.motor = VehicleMotor.of(vehicle)
	return vehicle
	
func update_next_point():
	var new_origin_index: int = self.get_next_node_index()
	self.wheels.set_origin_point(new_origin_index)
	self.wheels.set_target_point(new_origin_index +1)
	
func _physics_process(delta: float) -> void:
	if !self.motor.is_started: return
	var forward_vec := Vector3(0, 0, -7 * delta)
	translate(forward_vec)
	var current_section: TrackSection = self.wheels.current_section
	if (position.distance_to(self.get_next_node_pos()) <= 1):
		if current_section.end:
			reached_next_node.emit(current_section.end.index)
			update_next_point()
		else:
			self.motor.stop()
			
# == NODE GETTERS ==
func get_static_body() -> StaticBody3D:
	return self.get_child(0)
	
func get_next_node_pos() -> Vector3:
	if self.wheels.current_section.end:
		return self.wheels.current_section.end.position
	else:
		self.motor.stop()
		return self.wheels.current_track.get_end_pos()
	
func get_next_node_index() -> int:
	return self.wheels.target.index

func get_cam() -> Camera3D:
	return $Camera3D

func rotate_to(target_pos: Vector3):
	var rot_before := self.global_rotation
	self.look_at(target_pos, Vector3(0,1,0))
	var rot_target := global_rotation
	self.global_rotation = rot_before
	Loggie.info("Rotate from %s to %s" % [rot_before, rot_target])
	self.look_at(target_pos, Vector3(0,1,0))
	
func _on_world_ready():
	self.wheels.put_on_track()
	self.motor.start()
