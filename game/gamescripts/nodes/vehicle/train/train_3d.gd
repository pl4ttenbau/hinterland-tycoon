@icon("res://assets/icons/icon_locomotive.png")
class_name Train3D extends InventoryEntity3D

const EMPTY_SCENE_PATH = "res://scenes/subscenes/vehicle/train_3d.tscn"
const VEH_SPEED_MODIFIER: float = 50.0

signal on_vehicle_added(veh3d: Vehicle3D)
signal active_path_end_reached(reached_node: RailNodeData)

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

@export var is_reversed: bool = false

## A derailed train stays stopped until a future recovery action resets this flag.
@export var derailed: bool = false

## latest touched RailTrackNode
@export var last_node: RailNodeData

@export var current_segment: VehiclePathSegment

@export var current_station = NodeStationLink3D

static func _next_train_num() -> int:
	Train3D._last_train_num += 1
	return Train3D._last_train_num

#region Initialization
func _init() -> void:
	self.active_path_end_reached.connect(Callable(self, "_on_active_path_end_reached"))
	
func _enter_tree() -> void:
	SignalBus.scene_root_ready.connect(Callable(self, "_on_world_ready"))

func _ready() -> void:
	# create speed timer
	var speed_timer := Timer.new()
	speed_timer.wait_time = .1
	speed_timer.timeout.connect(Callable(self, "_on_speed_timer_tick"))
	self.add_child(speed_timer)
	speed_timer.start()
	self._place_vehicles()

static func of(_veh_type_key: String, _start_pos: VehicleStartPos) -> Train3D:
	var inst: Train3D = load(EMPTY_SCENE_PATH).instantiate()
	inst.spawn_locomotive(VehicleData.of(_veh_type_key), _start_pos)
	inst.init_segment_path()
	return inst

func _create_motor(_dir: Enums.PathDirection):
	self.motor = TrainMotor.of(_dir)
	self.motor.reversing.connect(Callable(self, "_on_motor_reversing"))
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
	## Vehicles added before entering the scene tree still need their carriage spacing.
	for attached_vehicle: Vehicle3D in self.vehicles:
		attached_vehicle.offset_to_first = attached_vehicle.calc_offset_to_first()
	self.on_vehicle_added.emit(veh3d)
#endregion

#region Vehicle Path
func init_segment_path():
	self.current_segment = VehiclePathSegmentBuilder.get_first_segment(self)
	var segment_path: ActiveRailVehiclePath = ActiveRailVehiclePath.of_segment(self, self.current_segment)
	self.add_child(segment_path)
	segment_path.name = "SegmentPath"
	## Honour the selected parking node instead of always starting at the track endpoint.
	self.m_passed_since_start = segment_path.curve.get_closest_offset(self.last_node.position)
	segment_path.ensure_lookahead(self.get_front_distance())
	self._update_segment_progress()
	if self.is_inside_tree():
		self._place_vehicles()

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
## Advance by distance and sample the path directly, without overlapping half-second tweens.
func move_forwards(delta_seconds: float):
	if self.derailed or self.get_active_path() == null:
		return
	## Speed is converted to world metres for this physics step.
	var tick_dist: float = self.motor.get_current_speed() * delta_seconds * VEH_SPEED_MODIFIER
	self.get_active_path().ensure_lookahead(self.get_front_distance() + tick_dist)
	## In reverse, wagons lead the locomotive and must reach buffers first.
	var available: float = maxf(0.0, self.get_active_path().curve.get_baked_length() - self.get_front_distance())
	self.increase_m_passed(minf(tick_dist, available))
	self._update_segment_progress()
	self._place_vehicles()
	if tick_dist >= available:
		self.active_path_end_reached.emit(self.current_segment.end_node)

## Carriages keep their physical order when the train travels backwards.
func get_vehicle_distance(veh3d: Vehicle3D) -> float:
	return self.m_passed_since_start + veh3d.offset_to_first * (1.0 if self.is_reversed else -1.0)

## The leading vehicle centre determines how much path must be available ahead.
func get_front_distance() -> float:
	## The locomotive leads normally; the last wagon leads after reversing.
	var front_distance: float = self.m_passed_since_start
	for veh3d: Vehicle3D in self.vehicles:
		front_distance = maxf(front_distance, self.get_vehicle_distance(veh3d))
	return front_distance

## A fork under the body of any vehicle is occupied, including a stopped wagon.
func occupies_path_distance(distance: float) -> bool:
	for veh3d: Vehicle3D in self.vehicles:
		## Include half the body length on either side of the vehicle centre.
		var half_length: float = veh3d.vehicle_obj.veh_type.length_metres * 0.5
		if absf(self.get_vehicle_distance(veh3d) - distance) <= half_length + 0.01:
			return true
	return false

## Derailment freezes the current transforms and prevents movement or reversal.
func derail() -> void:
	self.derailed = true
	self.motor.stop()

## Place every vehicle at its own curve sample, so rotation changes along each bend.
func _place_vehicles() -> void:
	if self.get_active_path() == null or self.get_active_path().curve.point_count < 2:
		return
	for veh3d: Vehicle3D in self.vehicles:
		## Sample in world space because the curve stores the rail network coordinates.
		var target_transf: Transform3D = self.get_active_path().get_transf_at_m_passed(self.get_vehicle_distance(veh3d))
		if self.is_reversed:
			## Reversing travel does not physically turn the locomotive or wagons around.
			target_transf = target_transf.rotated_local(Vector3.UP, PI)
		veh3d.global_transform = target_transf

## Keep the locomotive's current track separate from the provisional route ahead.
func _update_segment_progress() -> void:
	## Segment distances are measured on the assembled curve, not on track node counts.
	var segment_i: int = self.get_active_path().get_segment_index(self.m_passed_since_start)
	self.current_segment = self.get_active_path().segments[segment_i]
	self.m_passed_on_segment = self.m_passed_since_start
	if segment_i > 0:
		self.m_passed_on_segment -= self.get_active_path().segment_end_distances[segment_i - 1]
	self.motor.direction = self.current_segment.movement_dir

func increase_m_passed(delta_m: float):
	self.m_passed_on_segment += delta_m
	self.m_passed_since_start += delta_m
#endregion

#region Reverse
## Reverse the retained curve at the exact distance, keeping all vehicles in place.
func reverse_from_current_spot():
	if self.derailed or self.get_active_path() == null:
		return
	self.motor.stop()
	## Mirroring the distance preserves the same physical point on a reversed curve.
	var reversed_distance: float = self.get_active_path().curve.get_baked_length() - self.m_passed_since_start
	self.get_active_path().reverse_route()
	self.is_reversed = not self.is_reversed
	self.m_passed_since_start = reversed_distance
	self._update_segment_progress()
	self.get_active_path().ensure_lookahead(self.get_front_distance())
	self._place_vehicles()
	self.motor.start()
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

func _on_motor_reversing():
	self.reverse_from_current_spot()

func _physics_process(_delta: float) -> void:
	if self.derailed:
		if self.motor.is_started:
			self.motor.stop()
		return
	if self.motor.is_started:
		self.move_forwards(_delta)

func _on_active_path_end_reached(reached_node: RailNodeData):
	Loggie.info("Train %d reaches end of track %d" % [self.num, self.current_segment.track_num])
	Loggie.info("Reached node: %d at %v" % [reached_node.index, reached_node.position])
	self.motor.stop()

#endregion
