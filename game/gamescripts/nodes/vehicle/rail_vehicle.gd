@icon("res://assets/icons/icon_locomotive.png")
class_name RailVehicle extends VisibleObject

const SCENE_PATH = "res://assets/meshes/vehicles/rail/loco_faur/vehicle_loco_faur.tscn"

@export var vehicle_num: int

@export var motor: VehicleMotor

@export var direction: VehicleMotor.Direction

## latest touched RailTrackNode
@export var last_node: RailNodeData

signal reached_next_node(node_num: int)
signal reached_end_of_track(node_obj: RailNodeData)

func _enter_tree() -> void:
	SignalBus.scene_root_ready.connect(Callable(self, "_on_world_ready"))
	
func _ready() -> void:
	# create speed timer
	var speed_timer := Timer.new()
	speed_timer.wait_time = .1
	speed_timer.timeout.connect(Callable(self, "_on_speed_timer_tick"))
	self.add_child(speed_timer)
	speed_timer.start()

static func of(_starting_track: OuterRailTrack, _starts_at: int, 
		_dir: VehicleMotor.Direction) -> RailVehicle:
	var vehicle: RailVehicle = load(SCENE_PATH).instantiate()
	vehicle.direction = _dir
	vehicle.motor = VehicleMotor.of(vehicle)
	# save start node
	vehicle.last_node = _starting_track.track.get_rail_node(_starts_at)
	# vehicle.position = vehicle.last_node.position
	return vehicle
	
func _physics_process(delta: float) -> void:
	if self.motor.is_started:
		$VehiclePath/PathFollow3D.progress += .1

#region Node Getters
func get_static_body() -> StaticBody3D: return self.get_child(0)
	
func get_next_node_pos() -> Vector3:
	if self.current_section.target:
		return self.current_section.target.position
	else:
		self.motor.stop()
		return self.current_track.get_end_pos()
	
func get_next_node_index() -> int: return self.wheels.target.index

func get_cam() -> Camera3D: 
	return self.find_child("Camera3D", true)
#endregion

#region Callbacks
func _on_speed_timer_tick():
	if self.motor && self.motor.is_started:
		self.motor.on_motor_tick()
	
func _on_world_ready():
	self.motor.start()
#endregion
