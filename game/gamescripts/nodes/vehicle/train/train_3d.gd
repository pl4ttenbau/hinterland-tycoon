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

@export var motor: TrainMotor

@export var m_passed_since_start: float = 0.0
@export var m_passed_on_track: float = 0.0

## latest touched RailTrackNode
@export var last_node: RailNodeData

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
	inst.spawn_locomotive(VehicleData.of(_veh_type_key), _start_pos)
	return inst
	
func _create_motor(_dir: Enums.PathDirection):
	self.motor = TrainMotor.of(_dir)
	self.add_child(self.motor)
#endregion

#region Vehicle Spawning
func spawn_locomotive(veh_data: VehicleData, start_pos: VehicleStartPos):
	self._create_motor(start_pos.dir)
	# load vehicle 
	self.add_vehicle(Vehicle3D.of_vehicle_obj(veh_data, self), true)
	# set starting node
	self.last_node = start_pos.track_obj.get_rail_node(start_pos.node_index)

func spawn_wagon(veh_data: VehicleData):
	self.add_vehicle(Vehicle3D.of_vehicle_obj(veh_data, self), false)

func add_vehicle(veh3d: Vehicle3D, is_locomotive: bool = false):
	# add to lists
	self.vehicles.append(veh3d)
	if is_locomotive: self.locomotive = veh3d
	# create pathfollow node: move so far that it appears before the vehicle beyond
	var veh_path_follow := VehiclePathFollow.of_train_vehicle(self.count(), veh3d)
	# move train forwards by 1x its length before the new vehicle
	# TODO: works now?
	veh_path_follow.progress += self.length_in_m()
	$TrainPath.add_child(veh_path_follow)
#endregion

#region Size Getters
func count() -> int:
	return self.vehicles.size()
	
func length_in_m() -> float:
	var total_length: float = 0.0
	for attached_veh: Vehicle3D in self.vehicles:
		if attached_veh.vehicle_obj && attached_veh.vehicle_obj.veh_type:
			total_length += attached_veh.vehicle_obj.veh_type.length_metres
	return total_length
#endregion

#region Moving
func move_forwards(delta_seconds: float): 
	for path_child in $TrainPath.get_children():
		if path_child is PathFollow3D:
			var tick_dist: float = self.motor.get_current_speed() * delta_seconds * 33
			path_child.progress += tick_dist
#endregion

#region Node Children Getters
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
	if self.motor.is_started: self.move_forwards(_delta)
#endregion
