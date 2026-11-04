@icon("res://assets/icons/nodes_3d/icon_locomotive.svg")
class_name TrainMovement extends Node

## Convert the original motor speed scale into world metres per second.
const VEH_SPEED_MODIFIER: float = 50.0
## Maximum speed on the original motor scale; preserve the existing driving speed.
const MAX_ABS_SPEED: float = 0.12
## Preserve the former 0.005-per-0.1-second acceleration duration.
const SPEED_CHANGE_PER_SECOND: float = 0.05
## The service brake reaches zero in half the normal ramp time.
const BRAKE_RATE_MULTIPLIER: float = 2.0

signal started()
signal stopped()
signal reversing()
signal active_path_end_reached(reached_node: RailNodeData)

## Assigned by the train scene at instantiation, independently of this node's parent.
@export var train: Train3D
## Speed values and driver requests stay separate from the controller's tween.
var speed: VehicleSpeed = VehicleSpeed.new()
## The route keeps its own geometry, fork subscriptions and debug markers.
var active_path: ActiveRailVehiclePath
## Distance along the assembled route to the locomotive's centre.
@export var m_passed_since_start: float = 0.0
## Distance travelled within the segment currently under the locomotive.
@export var m_passed_on_segment: float = 0.0
## Carriages keep their facing and order when travelling backwards.
@export var is_reversed: bool = false
## Derailment prevents restart until a future recovery action resets this flag.
@export var derailed: bool = false
## Parking node used to build the initial route before simulation starts.
@export var last_node: RailNodeData
## The locomotive's segment is independent of provisional segments ahead.
@export var current_segment: VehiclePathSegment
## Direction of travel through the current track's node order.
@export var direction: Enums.PathDirection
## Starting is explicit; wiring dependencies never starts the train.
@export var is_started: bool = false
## Engine timestamp of the last explicit start, or -1 while stopped.
var running_msec: int = -1
## Only one tween may write the train's speed at a time.
var _speed_tween: Tween
## Distinguish tween samples from external writes that need a fresh ramp.
var _applying_speed_sample: bool = false

## Expose the existing speed scale for the speedometer.
var current_speed_percentage: float:
	get(): return self.speed.current
	set(value): self.speed.current = value

## Elapsed engine time since start, preserving the former motor API.
var running_time: int:
	get(): return Time.get_ticks_msec() - self.running_msec if self.is_started else -1

## Wire references and signals before entering the tree; no tween is created here.
func configure(owner_train: Train3D) -> void:
	self.train = owner_train
	## Move before model effects sample world displacement, preserving the previous parent-first order.
	self.process_physics_priority = self.train.process_physics_priority - 1
	if not self.speed.target_changed.is_connected(self._on_target_speed_changed):
		self.speed.target_changed.connect(self._on_target_speed_changed)
		self.speed.brake_changed.connect(self._on_brake_changed)
		self.speed.changed.connect(self._on_current_speed_changed)
		self.active_path_end_reached.connect(self._on_active_path_end_reached)
	if not SignalBus.scene_root_ready.is_connected(self._on_world_ready):
		SignalBus.scene_root_ready.connect(self._on_world_ready)

## A start requested before insertion waits until a node-bound tween can be created.
func _enter_tree() -> void:
	self._retarget_speed()

## Placement needs world transforms, but all dependency wiring has already happened.
func _ready() -> void:
	self.place_vehicles()

## Configure the route and parking position before the train is inserted into the scene.
func init_segment_path() -> void:
	self.current_segment = VehiclePathSegmentBuilder.get_first_segment(self)
	self.active_path = ActiveRailVehiclePath.of_segment(self, self.current_segment)
	self.active_path.name = "SegmentPath"
	self.train.add_child(self.active_path)
	self.m_passed_since_start = self.active_path.curve.get_closest_offset(self.last_node.position)
	self.active_path.ensure_lookahead(self.get_front_distance())
	self.update_segment_progress()
	if self.train.is_inside_tree():
		self.place_vehicles()

## Starting preserves the selected target speed and any applied service brake.
func start() -> bool:
	if self.derailed or not is_instance_valid(self.train):
		return false
	self.is_started = true
	self.running_msec = Time.get_ticks_msec()
	self._retarget_speed()
	self.started.emit()
	return true

## Stop cancels the tween before zeroing speed, so it cannot accelerate again afterwards.
func stop() -> void:
	self.is_started = false
	self.running_msec = -1
	self._cancel_speed_tween()
	self.speed.current = 0.0
	self.stopped.emit()

## Replace an interrupted ramp from its actual speed, keeping only one writer active.
func _retarget_speed() -> void:
	self._cancel_speed_tween()
	if not self.is_started or not self.is_inside_tree() or self.derailed:
		return
	## Braking overrides traction without replacing the driver's requested target.
	var effective_target: float = 0.0 if self.speed.brake_applied else self.speed.target
	## Smaller speed changes take proportionally less time, matching the original ramp.
	var distance: float = absf(effective_target - self.speed.current)
	if is_zero_approx(distance):
		return
	## The brake multiplier shortens the duration while retaining quadratic easing.
	var rate: float = SPEED_CHANGE_PER_SECOND * (BRAKE_RATE_MULTIPLIER if self.speed.brake_applied else 1.0)
	self._speed_tween = self.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	self._speed_tween.tween_method(self._apply_speed_sample, self.speed.current, effective_target, distance / rate).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	self._speed_tween.finished.connect(self._on_speed_tween_finished)

## Updating through the normal setter keeps speedometer and exhaust signals working.
func _apply_speed_sample(value: float) -> void:
	self._applying_speed_sample = true
	self.speed.current = value
	self._applying_speed_sample = false

## Killing the previous tween also prevents its completion callback from touching a newer ramp.
func _cancel_speed_tween() -> void:
	if self._speed_tween != null and self._speed_tween.is_valid():
		self._speed_tween.kill()
	self._speed_tween = null

## Release the completed tween reference without changing the final speed sample.
func _on_speed_tween_finished() -> void:
	self._speed_tween = null

## Target changes while stopped merely store the request for the next explicit start.
func _on_target_speed_changed(_value: float) -> void:
	self._retarget_speed()

## Applying or releasing the brake replaces the active ramp from its current speed.
func _on_brake_changed(_applied: bool) -> void:
	self._retarget_speed()

## External speed corrections also interrupt the ramp, while tween samples do not.
func _on_current_speed_changed(_value: float) -> void:
	if not self._applying_speed_sample:
		self._retarget_speed()

## Keep the existing speed scale while moving all speed control into this component.
func get_current_speed() -> float:
	return self.speed.current * MAX_ABS_SPEED

## Route users access the configured path directly instead of assuming a child-node layout.
func get_active_path() -> ActiveRailVehiclePath:
	return self.active_path

## Advance by distance and sample the path directly, without overlapping half-second tweens.
func move_forwards(delta_seconds: float) -> void:
	if self.derailed or self.get_active_path() == null:
		return
	## Speed is converted to world metres for this physics step.
	var tick_dist: float = self.get_current_speed() * delta_seconds * VEH_SPEED_MODIFIER
	self.get_active_path().ensure_lookahead(self.get_front_distance() + tick_dist)
	## In reverse, wagons lead the locomotive and must reach buffers first.
	var available: float = maxf(0.0, self.get_active_path().curve.get_baked_length() - self.get_front_distance())
	self.increase_m_passed(minf(tick_dist, available))
	self.update_segment_progress()
	self.place_vehicles()
	if tick_dist >= available:
		self.active_path_end_reached.emit(self.current_segment.end_node)

## Carriages keep their physical order when the train travels backwards.
func get_vehicle_distance(veh3d: Vehicle3D) -> float:
	return self.m_passed_since_start + veh3d.offset_to_first * (1.0 if self.is_reversed else -1.0)

## The leading vehicle centre determines how much path must be available ahead.
func get_front_distance() -> float:
	## The locomotive leads normally; the last wagon leads after reversing.
	var front_distance: float = self.m_passed_since_start
	for veh3d: Vehicle3D in self.train.vehicles:
		front_distance = maxf(front_distance, self.get_vehicle_distance(veh3d))
	return front_distance

## A fork under the body of any vehicle is occupied, including a stopped wagon.
func occupies_path_distance(distance: float) -> bool:
	for veh3d: Vehicle3D in self.train.vehicles:
		## Include half the body length on either side of the vehicle centre.
		var half_length: float = veh3d.vehicle_obj.veh_type.length_metres * 0.5
		if absf(self.get_vehicle_distance(veh3d) - distance) <= half_length + 0.01:
			return true
	return false

## Derailment freezes the current transforms and prevents movement or reversal.
func derail() -> void:
	self.derailed = true
	self.stop()

## Place every vehicle at its own curve sample, so rotation changes along each bend.
func place_vehicles() -> void:
	if self.get_active_path() == null or self.get_active_path().curve.point_count < 2:
		return
	for veh3d: Vehicle3D in self.train.vehicles:
		## Sample in world space because the curve stores the rail network coordinates.
		var target_transf: Transform3D = self.get_active_path().get_transf_at_m_passed(self.get_vehicle_distance(veh3d))
		if self.is_reversed:
			## Reversing travel does not physically turn the locomotive or wagons around.
			target_transf = target_transf.rotated_local(Vector3.UP, PI)
		veh3d.global_transform = target_transf

## Keep the locomotive's current track separate from the provisional route ahead.
func update_segment_progress() -> void:
	## Segment distances are measured on the assembled curve, not on track node counts.
	var segment_i: int = self.get_active_path().get_segment_index(self.m_passed_since_start)
	self.current_segment = self.get_active_path().segments[segment_i]
	self.m_passed_on_segment = self.m_passed_since_start
	if segment_i > 0:
		self.m_passed_on_segment -= self.get_active_path().segment_end_distances[segment_i - 1]
	self.direction = self.current_segment.movement_dir

func increase_m_passed(delta_m: float) -> void:
	self.m_passed_on_segment += delta_m
	self.m_passed_since_start += delta_m
#endregion

#region Reverse
## Reverse the retained curve at the exact distance, keeping all vehicles in place.
func reverse_from_current_spot() -> void:
	if self.derailed or self.get_active_path() == null:
		return
	self.stop()
	## Mirroring the distance preserves the same physical point on a reversed curve.
	var reversed_distance: float = self.get_active_path().curve.get_baked_length() - self.m_passed_since_start
	self.get_active_path().reverse_route()
	self.is_reversed = not self.is_reversed
	self.reversing.emit()
	self.m_passed_since_start = reversed_distance
	self.update_segment_progress()
	self.get_active_path().ensure_lookahead(self.get_front_distance())
	self.place_vehicles()
	self.start()
#endregion

## Simulation updates belong to movement rather than the train's scene composition.
func _physics_process(delta: float) -> void:
	if self.derailed:
		if self.is_started:
			self.stop()
		return
	if self.is_started:
		self.move_forwards(delta)

## Preserve the existing world-start signal as the explicit simulation start boundary.
func _on_world_ready() -> void:
	self.start()

## Reaching an unconnected track end stops the train before a later physics step can overshoot.
func _on_active_path_end_reached(reached_node: RailNodeData) -> void:
	Loggie.info("Train %d reaches end of track %d" % [self.train.num, self.current_segment.track_num])
	Loggie.info("Reached node: %d at %v" % [reached_node.index, reached_node.position])
	self.stop()

## A removed controller must not retain a running speed tween.
func _exit_tree() -> void:
	self.stop()
