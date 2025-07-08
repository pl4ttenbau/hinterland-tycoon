@icon("res://assets/icons/icon_locomotive.png")
class_name RailVehicle extends VisibleObject

const SCENE_PATH = "res://assets/meshes/vehicles/loco_faur/vehicle_loco_faur.tscn"

@export var vehicle_num: int
@export var wheels: VehicleWheels
@export var motor: VehicleMotor

signal reached_next_node(node_num: int)
signal reached_end_of_track(node_obj: RailNodeData)
signal entered()
signal exited()

func _enter_tree() -> void:
	SignalBus.scene_root_ready.connect(Callable(self, "_on_world_ready"))
	
func _ready() -> void:
	# create speed timer
	var speed_timer := Timer.new()
	speed_timer.wait_time = .1
	speed_timer.timeout.connect(Callable(self, "_on_speed_timer_tick"))
	self.add_child(speed_timer)
	speed_timer.start()

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
	var speed_percent := self.motor.current_speed_percentage
	var forward_vec := Vector3(0, 0, -7 * delta) * speed_percent
	translate(forward_vec)
	var current_section := self.wheels.current_section
	if (position.distance_to(self.get_next_node_pos()) <= 1):
		if current_section.target:
			reached_next_node.emit(current_section.target.index)
			update_next_point()
		else:
			var last_node: RailNodeData = current_section.track.get_end_node()
			self.wheels.set_on_connected_track(last_node)
			
#region Node Getters
func get_static_body() -> StaticBody3D:
	return self.get_child(0)
	
func get_next_node_pos() -> Vector3:
	if self.wheels.current_section.target:
		return self.wheels.current_section.target.position
	else:
		self.motor.stop()
		return self.wheels.current_track.get_end_pos()
	
func get_next_node_index() -> int:
	return self.wheels.target.index

func get_cam() -> Camera3D:
	return $Camera3D
#endregion

func _on_speed_timer_tick():
	if self.motor && self.motor.is_started:
		self.motor.on_motor_tick()

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
