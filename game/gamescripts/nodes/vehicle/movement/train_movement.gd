@icon("res://assets/icons/nodes_3d/icon_locomotive.svg")
class_name TrainMovement extends Node

signal started()
signal stopped()
signal reversing()
signal active_path_end_reached(reached_node: RailNodeData)

## Assigned by the train scene at instantiation, independently of this node's parent.
@export var train: Train3D
## Driver requests and the speed shown in the UI, as fractions of the consist's maximum speed.
var speed: VehicleSpeed = VehicleSpeed.new()
## Physical speed along the route in metres per second; `speed.current` mirrors it as a fraction.
var speed_mps: float = 0.0
## The route keeps its own geometry, fork subscriptions and debug markers.
var active_path: ActiveRailVehiclePath
## Distance along the assembled route to the first vehicle's centre.
@export var m_passed_since_start: float = 0.0
## Distance travelled within the segment currently under the first vehicle.
@export var m_passed_on_segment: float = 0.0
## Carriages keep their facing and order when travelling backwards.
@export var is_reversed: bool = false
## Derailment prevents restart until a future recovery action resets this flag.
@export var derailed: bool = false
## Parking node used to build the initial route before simulation starts.
@export var last_node: RailNodeData
## The first vehicle's segment is independent of provisional segments ahead.
@export var current_segment: VehiclePathSegment
## Direction of travel through the current track's node order.
@export var direction: Enums.PathDirection
## Starting is explicit; wiring dependencies never starts the train.
@export var is_started: bool = false
## Engine timestamp of the last explicit start, or -1 while stopped.
var running_msec: int = -1
## Distinguish this controller's own speed updates from external corrections.
var _writing_speed: bool = false
var _rollout_end_distance: float = INF

## Expose the existing speed scale for the speedometer.
var current_speed_percentage: float:
	get(): return self.speed.current
	set(value): self.speed.current = value

## Elapsed engine time since start, preserving the former motor API.
var running_time: int:
	get(): return Time.get_ticks_msec() - self.running_msec if self.is_started else -1

## Wire references and signals before entering the tree.
func configure(owner_train: Train3D) -> void:
	self.train = owner_train
	## Move before model effects sample world displacement, preserving the previous parent-first order.
	self.process_physics_priority = self.train.process_physics_priority - 1
	if not self.speed.changed.is_connected(self._on_current_speed_changed):
		self.speed.changed.connect(self._on_current_speed_changed)
		self.active_path_end_reached.connect(self._on_active_path_end_reached)
	if not SignalBus.scene_root_ready.is_connected(self._on_world_ready):
		SignalBus.scene_root_ready.connect(self._on_world_ready)

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
	self.started.emit()
	return true

## Limit the automatic depot departure to a distance along the active path.
func start_rollout(distance: float) -> void:
	self._rollout_end_distance = self.m_passed_since_start + distance
	if not self.start():
		self._rollout_end_distance = INF

func cancel_rollout() -> void:
	if is_finite(_rollout_end_distance):
		_rollout_end_distance = INF
		speed.target = 0.0

## Stopping switches the controller off and zeroes the speed immediately.
func stop() -> void:
	self._rollout_end_distance = INF
	self.is_started = false
	self.running_msec = -1
	self._set_speed_mps(0.0)
	self.stopped.emit()

#region Speed
## Consist limits are read on demand, so coupling and splitting need no notification.
func get_dynamics() -> TrainDynamics:
	if not is_instance_valid(self.train):
		return TrainDynamics.new()
	return TrainDynamics.of_vehicles(self.train.vehicles)

func get_max_speed_mps() -> float:
	return self.get_dynamics().max_speed_mps

func get_speed_mps() -> float:
	return self.speed_mps

## Distance needed to stop from the current speed with service braking.
func get_stopping_distance() -> float:
	return TrainDynamics.stopping_distance(self.speed_mps)

## Distance the train may still travel before it must stand: the rollout limit, the end of the known route,
## or the stopping point before the first signal ahead that shows stop.
func get_movement_authority() -> float:
	var remaining: float = self._rollout_end_distance - self.m_passed_since_start
	var path: ActiveRailVehiclePath = self.get_active_path()
	if path != null:
		remaining = minf(remaining, path.curve.get_baked_length() - self.get_front_distance())
	remaining = minf(remaining, self.get_signal_authority())
	return maxf(remaining, 0.0)

## Distance to the stopping point before the first signal ahead on the known route that shows stop.
## A signal the leading vehicle's nose has already passed no longer applies.
func get_signal_authority() -> float:
	var store: RailSignalStore = RailSignalBlocks.get_store()
	var path: ActiveRailVehiclePath = self.get_active_path()
	if store == null or store.signals.is_empty() or path == null or not is_instance_valid(self.train):
		return INF
	var front: float = self.get_front_distance()
	var lead_half: float = 0.0
	for veh3d: Vehicle3D in self.train.vehicles:
		if is_equal_approx(self.get_vehicle_distance(veh3d), front):
			lead_half = maxf(lead_half, RailSignalBlocks.half_length(veh3d))
	var ahead: Array = []
	for segment_i: int in range(path.segments.size()):
		var seg_start: float = 0.0 if segment_i == 0 else path.segment_end_distances[segment_i - 1]
		var seg_end: float = path.segment_end_distances[segment_i]
		if seg_end <= front:
			continue
		var segment: VehiclePathSegment = path.segments[segment_i]
		for rail_signal: RailSignalData in store.get_on_track(segment.track_num):
			if not rail_signal.protects(segment.movement_dir):
				continue
			var distance: float = RailSignalBlocks.track_to_path_distance(segment, seg_start, seg_end, rail_signal.offset)
			if distance > front + lead_half:
				ahead.append([distance, rail_signal, segment.movement_dir])
	if ahead.is_empty():
		return INF
	ahead.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var spans: Dictionary = RailSignalBlocks.occupancy(GlobalState.trains, self.train)
	for entry: Array in ahead:
		if not RailSignalBlocks.is_block_clear(entry[1], entry[2], store, spans):
			return entry[0] - lead_half - RailSignalBlocks.STOP_MARGIN_METRES - front
	return INF

## Accelerate towards the driver's target, or brake for the target, the brake control or the authority end.
func update_speed(delta_seconds: float) -> void:
	if self.derailed or not self.is_started:
		return
	var dynamics: TrainDynamics = self.get_dynamics()
	var target_mps: float = 0.0 if self.speed.brake_applied else clampf(self.speed.target, 0.0, 1.0) * dynamics.max_speed_mps
	## The route ahead must be known for at least the distance needed to stop from the next speed;
	## the path adds its own margin beyond that.
	if self.get_active_path() != null:
		var next_speed: float = self.speed_mps + dynamics.traction_acceleration(self.speed_mps) * delta_seconds
		self.get_active_path().ensure_lookahead(self.get_front_distance() + TrainDynamics.stopping_distance(next_speed))
	var authority_mps: float = TrainDynamics.approach_speed(self.get_movement_authority())
	var desired: float = minf(target_mps, authority_mps)
	var next: float = self.speed_mps
	if next < desired:
		next = minf(desired, next + dynamics.traction_acceleration(next) * delta_seconds)
	elif next > desired:
		## Following the stopping curve: each step lands back on it, so the effective rate is the service rate.
		var braking: bool = self.speed.brake_applied or next > authority_mps
		var deceleration: float = TrainDynamics.BRAKE_DECELERATION if braking else TrainDynamics.SERVICE_DECELERATION
		next = maxf(desired, next - deceleration * delta_seconds)
	self._set_speed_mps(next, dynamics.max_speed_mps)

## Keep the fraction shown by the UI in step with the physical speed.
func _set_speed_mps(value: float, max_speed: float = -1.0) -> void:
	self.speed_mps = maxf(value, 0.0)
	if max_speed < 0.0:
		max_speed = self.get_max_speed_mps()
	var fraction: float = self.speed_mps / max_speed if max_speed > 0.0 else 0.0
	## Avoid a change signal every physics tick while the speed holds.
	if fraction == self.speed.current:
		return
	self._writing_speed = true
	self.speed.current = fraction
	self._writing_speed = false

## External corrections of the fraction (tests, previews, coupling) set the physical speed.
func _on_current_speed_changed(value: float) -> void:
	if not self._writing_speed:
		self.speed_mps = maxf(value, 0.0) * self.get_max_speed_mps()
#endregion

## Route users access the configured path directly instead of assuming a child-node layout.
func get_active_path() -> ActiveRailVehiclePath:
	return self.active_path

## Advance by the current speed for this step, never past the rollout limit or the route end.
func move_forwards(delta_seconds: float) -> void:
	if self.derailed or self.get_active_path() == null:
		return
	var tick_dist: float = self.speed_mps * delta_seconds
	if is_zero_approx(tick_dist):
		return
	var rollout_remaining: float = self._rollout_end_distance - self.m_passed_since_start
	tick_dist = minf(tick_dist, rollout_remaining)
	self.get_active_path().ensure_lookahead(self.get_front_distance() + tick_dist)
	## In reverse, wagons lead the locomotive and must reach buffers first.
	var available: float = maxf(0.0, self.get_active_path().curve.get_baked_length() - self.get_front_distance())
	self.increase_m_passed(minf(tick_dist, available))
	self.update_segment_progress()
	self.place_vehicles()
	if tick_dist >= available:
		self.active_path_end_reached.emit(self.current_segment.end_node)
	elif tick_dist >= rollout_remaining:
		## Stay ready for the driver's next speed request.
		self._rollout_end_distance = INF
		self.speed.target = 0.0
		self._set_speed_mps(0.0)

## Carriages keep their physical order when the train travels backwards.
func get_vehicle_distance(veh3d: Vehicle3D) -> float:
	return self.m_passed_since_start + veh3d.offset_to_first * (1.0 if self.is_reversed else -1.0)

func get_vehicle_segment(veh3d: Vehicle3D) -> VehiclePathSegment:
	return active_path.segments[active_path.get_segment_index(get_vehicle_distance(veh3d))]

func is_parked() -> bool:
	return not derailed and is_zero_approx(speed.current) \
		and (not is_started or speed.brake_applied or is_zero_approx(speed.target))

## The leading vehicle centre determines how much path must be available ahead.
func get_front_distance() -> float:
	## The first vehicle leads normally; the last vehicle leads after reversing.
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
	var path: ActiveRailVehiclePath = self.get_active_path()
	if path == null or path.curve.point_count < 2:
		return
	for veh3d: Vehicle3D in self.train.vehicles:
		var distance: float = self.get_vehicle_distance(veh3d)
		var target_transf: Transform3D = get_rail_transform(distance)
		if is_reversed != veh3d.faces_rear:
			target_transf = target_transf.rotated_local(Vector3.UP, PI)
		veh3d.global_transform = target_transf

func get_rail_transform(distance: float) -> Transform3D:
	var pose: Transform3D = active_path.get_transf_at_m_passed(distance)
	var segment: VehiclePathSegment = active_path.segments[active_path.get_segment_index(distance)]
	pose.origin += pose.basis.y * segment.as_rail_track().get_rail_head_height()
	return pose

## Keep the first vehicle's current track separate from the provisional route ahead.
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
		self.update_speed(delta)
		self.move_forwards(delta)

## Preserve the existing world-start signal as the explicit simulation start boundary.
func _on_world_ready() -> void:
	self.start()

## Reaching an unconnected track end stops the train before a later physics step can overshoot.
func _on_active_path_end_reached(reached_node: RailNodeData) -> void:
	Loggie.info("Train %d reaches end of track %d" % [self.train.num, self.current_segment.track_num])
	Loggie.info("Reached node: %d at %v" % [reached_node.index, reached_node.position])
	self.stop()

## A removed controller leaves its train stopped.
func _exit_tree() -> void:
	self.stop()
