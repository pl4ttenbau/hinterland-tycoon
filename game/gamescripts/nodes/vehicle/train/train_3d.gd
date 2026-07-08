@icon("res://assets/icons/icon_locomotive.png")
class_name Train3D extends InventoryEntity3D

const EMPTY_SCENE_PATH = "res://scenes/subscenes/vehicle/train_3d.tscn"
const VEH_SPEED_MODIFIER: float = 50.0

signal on_vehicle_added(veh3d: Vehicle3D)

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
@export var m_passed_on_segment: float = 0.0

## latest touched RailTrackNode
@export var last_node: RailNodeData

@export var current_segment: VehiclePathSegment

@export var current_station = NodeStationLink3D

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
	inst.init_segment_path()
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
	var num_in_train: int = self.vehicles.size()
	veh3d.num_in_train = num_in_train
	self.vehicles.append(veh3d)
	if is_locomotive: 
		self.locomotive = veh3d
	$TrainVehicles.add_child(veh3d)
	self.on_vehicle_added.emit(veh3d)
#endregion

#region Vehicle Path
func init_segment_path():
	self.current_segment = VehiclePathSegmentBuilder.get_first_segment(self)
	var segment_path: ActiveRailVehiclePath = ActiveRailVehiclePath.of_segment(self.current_segment)
	self.add_child(segment_path)
	segment_path.name = "SegmentPath"

## after locomotive reaches end of current segment, 
func add_next_segment_or_stop():
	# update next segment
	var previous_segment: VehiclePathSegment = self.current_segment
	self.current_segment = VehiclePathSegmentBuilder.find_next_segment(self.current_segment)
	if self.current_segment.previous:
		self.current_segment.previous = previous_segment
		# extend rail path
		self.get_active_path().add_segment(self.current_segment)
	else:
		self.motor.stop()
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
	# calculate movement since last tick
	var tick_dist: float = self.motor.get_current_speed() * delta_seconds * VEH_SPEED_MODIFIER
	if !self.get_active_path() || !self.get_active_path().curve: return
	self.increase_m_passed(tick_dist)
	# reached end of path? add next segmenr or stop
	var active_path_len: float = self.get_active_path().curve.get_baked_length()
	if self.m_passed_since_start > active_path_len:
		Loggie.info("Train %d reaches end of track %d" % [self.num, self.current_segment.track_num])
		self.add_next_segment_or_stop()
	# move every vehicle in train forwards on path
	for veh3d: Vehicle3D in self.vehicles:
		var m_passed: float = self.m_passed_since_start - veh3d.offset_to_first
		if m_passed < 0: m_passed = 0
		var target_transf := self._get_target_transf_at_m_passed(m_passed)
		# tween towards target transform
		var transf_tween = veh3d.create_tween()
		transf_tween.tween_property(veh3d, "global_transform", target_transf, .5)

func increase_m_passed(delta_m: float):
	self.m_passed_on_segment += delta_m
	self.m_passed_since_start += delta_m

func _get_target_transf_at_m_passed(m_passed: float) -> Transform3D:
	var train_curve: Curve3D = self.get_active_path().curve
	var target_transf := train_curve.sample_baked_with_rotation(m_passed, true)
	# only turn vertically
	target_transf = target_transf.rotated_local(Vector3(1, 0, 0), 0)
	target_transf = target_transf.rotated_local(Vector3(0, 0, 1), 0)
	return target_transf
#endregion

#region Node Children Getters
func get_static_body() -> StaticBody3D: return self.get_child(0)

func get_next_node_index() -> int: return self.wheels.target.index

func get_cam() -> Camera3D:
	var model_cam: Camera3D = self.locomotive.find_child("Camera3D", true)
	if !model_cam: Loggie.error("Cannot find camera in vehicle model \"%s\"" % self.locomotive.name)
	return model_cam

func get_active_path() -> ActiveRailVehiclePath:
	if self.has_node("SegmentPath"):
		return $SegmentPath as ActiveRailVehiclePath
	return null
#endregion

#region Callbacks
func _on_speed_timer_tick():
	if self.motor && self.motor.is_started:
		self.motor.on_motor_tick()

func _on_world_ready():
	self.motor.start()

func _physics_process(_delta: float) -> void:
	if self.motor.is_started: 
		self.move_forwards(_delta)
#endregion
