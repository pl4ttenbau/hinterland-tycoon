@icon("res://assets/icons/icon_locomotive.png")
class_name Train3D extends VisibleObject

const EMPTY_SCENE_PATH = "res://scenes/subscenes/vehicle/train_3d.tscn"

static var _last_train_num: int = 0

@export var num: int

@export var train_obj: TrainData:
	get(): return self.entity as TrainData
	set(value):
		self.entity = value
		
@export var vehicles: Array[Vehicle3D] = []

@export var locomotive: Vehicle3D

@export var motor: VehicleMotor

## latest touched RailTrackNode
@export var last_node: RailNodeData

@export var vehicles_count: int = 0

static func _next_train_num() -> int:
	Train3D._last_train_num += 1
	return Train3D._last_train_num

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

static func of(_veh_type_key: String, _start_pos: VehicleStartPos) -> Train3D:
	var inst: Train3D = load(EMPTY_SCENE_PATH).instantiate()
	inst.spawn_vehicle(VehicleData.of(_veh_type_key), _start_pos)
	return inst
	
func _create_motor(_dir: Enums.PathDirection):
	var _motor := VehicleMotor.of(self)
	_motor.direction = _dir
	self.motor = _motor
	self.add_child(_motor)
#endregion

#region Vehicle Spawning
func spawn_vehicle(veh_data: VehicleData, start_pos: VehicleStartPos):
	self._create_motor(start_pos.dir)
	# load vehicle 
	var mesh_scene_path = veh_data.veh_type.model_scene_path
	var veh3d = load(mesh_scene_path).instantiate()
	self.add_vehicle(veh3d, true)
	# set starting node
	self.last_node = start_pos.track_obj.get_rail_node(start_pos.node_index)
	
func add_vehicle(veh3d: Vehicle3D, is_locomotive: bool = false):
	self.vehicles_count += 1
	# add to lists
	self.vehicles.append(veh3d)
	if is_locomotive: self.locomotive = veh3d
	# create pathfollow node
	var veh_follow = self.add_path_follow()
	veh_follow.add_child(veh3d)
	
func add_path_follow() -> PathFollow3D:
	var veh_follow := PathFollow3D.new()
	veh_follow.loop = false
	veh_follow.use_model_front = true
	veh_follow.name = "PathFollow_Vehicle_%d" % self.vehicles_count
	$TrainPath.add_child(veh_follow)
	return veh_follow
#endregion

#region Node Getters
func get_static_body() -> StaticBody3D: return self.get_child(0)
	
func get_next_node_index() -> int: return self.wheels.target.index

func get_cam() -> Camera3D:
	var model_cam: Camera3D = self.locomotive.find_child("Camera3D", true)
	if !model_cam: Loggie.error("Cannot find camera in vehicle model \"%s\"" % self.locomotive.name)
	return model_cam
	
func get_path_follow(num_in_train: int) -> PathFollow3D:
	var node_name: String = "PathFollow_Vehicle%d" % num_in_train
	return $TrainPath.get_node(node_name)
#endregion

#region Callbacks
func _on_speed_timer_tick():
	if self.motor && self.motor.is_started:
		self.motor.on_motor_tick()
	
func _on_world_ready():
	self.motor.start()
	
func _physics_process(_delta: float) -> void:
	if self.motor.is_started:
		for path_child in $TrainPath.get_children():
			if path_child is PathFollow3D:
				path_child.progress += self.motor.get_current_speed()
#endregion
