@icon("res://assets/icons/icon_locomotive.png")
class_name PathedVehicle3D extends VisibleObject

const EMPTY_SCENE_PATH = "res://scenes/subscenes/vehicle/vehicle_with_path_3d.tscn"

@export var vehicle_obj: RailVehicleData:
	get(): return self.entity as RailVehicleData
	set(value):
		self.entity = value
		
@export var model3d: VehicleModel3D:
	get(): return model3d
	set(value):
		model3d = value
		self.find_child("PathFollow3D", true).add_child(model3d)

@export var motor: VehicleMotor

## latest touched RailTrackNode
@export var last_node: RailNodeData

#region Definition: Signals
@warning_ignore("unused_signal")
signal reached_next_node(node_num: int)

@warning_ignore("unused_signal")
signal reached_end_of_track(node_obj: RailNodeData)
#endregion

#region Initialization
func _enter_tree() -> void:
	SignalBus.scene_root_ready.connect(Callable(self, "_on_world_ready"))
	
func _ready() -> void:
	# create speed timer
	var speed_timer := Timer.new()
	speed_timer.wait_time = .1
	speed_timer.timeout.connect(Callable(self, "_on_speed_timer_tick"))
	self.add_child(speed_timer)
	speed_timer.start()

static func of(_veh_type_key: String, start_pos: VehicleStartPos) -> PathedVehicle3D:
	# get vehicle type
	var veh_obj := RailVehicleData.of(_veh_type_key)
	# var scene_path = veh_obj.veh_type.scene_path
	# instanciate correct scene
	# var inst: PathedVehicle3D = load(scene_path).instantiate()
	var inst: PathedVehicle3D = load(EMPTY_SCENE_PATH).instantiate()
	inst.vehicle_obj = veh_obj
	inst._load_and_add_mesh()
	inst.set_onto_track(start_pos)
	return inst
	
func _load_and_add_mesh():
	var mesh_scene_path = self.vehicle_obj.veh_type.model_scene_path
	self.model3d = load(mesh_scene_path).instantiate()
	
func _create_motor(_dir: Enums.PathDirection):
	var _motor := VehicleMotor.of(self)
	_motor.direction = _dir
	self.add_child(_motor)
#endregion

func set_onto_track(start_pos: VehicleStartPos):
	self._create_motor(start_pos.dir)
	# save start node
	self.last_node = start_pos.track_obj.get_rail_node(start_pos.node_index)
	# vehicle.position = vehicle.last_node.position
	
func _physics_process(_delta: float) -> void:
	if self.motor.is_started:
		$VehiclePath/PathFollow3D.progress += self.motor.get_current_speed()

#region Node Getters
func get_static_body() -> StaticBody3D: return self.get_child(0)
	
func get_next_node_index() -> int: return self.wheels.target.index

func get_cam() -> Camera3D: 
	var model_cam: Camera3D = self.model3d.find_child("Camera3D", true)
	if !model_cam: Loggie.error("Cannot find camera in vehicle model \"%s\"" % self.model3d.name)
	return model_cam
#endregion

#region Callbacks
func _on_speed_timer_tick():
	if self.motor && self.motor.is_started:
		self.motor.on_motor_tick()
	
func _on_world_ready():
	self.motor.start()
#endregion
