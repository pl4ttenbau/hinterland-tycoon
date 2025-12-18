@icon("res://assets/icons/icon_locomotive.png")
class_name RailVehicle3D extends VisibleObject

@export var vehicle_num: int

@export var motor: VehicleMotor

@export var direction: VehicleMotor.Direction

@export var type_obj: RailVehicleType

## latest touched RailTrackNode
@export var last_node: RailNodeData

@warning_ignore("unused_signal")
signal reached_next_node(node_num: int)

@warning_ignore("unused_signal")
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

static func of(_veh_type_key: String, start_pos: VehicleStartPos) -> RailVehicle3D:
	# get vehicle type
	var veh_type_obj := RailVehicleType.get_by_key(_veh_type_key)
	# instanciate correct scene
	var vehicle: RailVehicle3D = load(veh_type_obj.get_mesh_path()).instantiate()
	vehicle.type_obj = veh_type_obj
	vehicle.set_onto_track(start_pos)
	return vehicle
	
func set_onto_track(start_pos: VehicleStartPos):
	self.direction = start_pos.dir
	self.motor = VehicleMotor.of(self)
	# save start node
	self.last_node = start_pos.track_obj.get_rail_node(start_pos.node_index)
	# vehicle.position = vehicle.last_node.position
	
static func load_vehicle_type_obj(_veh_type_key: String) -> RailVehicleType:
	var veh_type_obj: RailVehicleType = null
	for veh_type: RailVehicleType in GameTypes.vehicle_types:
		if veh_type.key == _veh_type_key:
			veh_type_obj = veh_type
	return veh_type_obj
	
func _physics_process(_delta: float) -> void:
	if self.motor.is_started:
		$VehiclePath/PathFollow3D.progress += self.motor.get_current_speed()

#region Node Getters
func get_static_body() -> StaticBody3D: return self.get_child(0)
	
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
