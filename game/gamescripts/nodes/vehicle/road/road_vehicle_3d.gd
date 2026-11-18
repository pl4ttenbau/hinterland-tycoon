## One physical vehicle: the player supplies free steering, otherwise the route
## supplies steering and speed requests. Scripted motion (endpoint U-turns, and
## optionally whole routes) temporarily uses a collision-checked kinematic pose;
## manual driving always retains wheel physics.
class_name RoadVehicle3D extends VehicleBody3D

## Emitted once per assigned driving path after its terminal stop.
signal route_finished()

## Global switch: when true, automatic driving places every road vehicle exactly
## on its route curve (kinematic, collision-checked) instead of steering with
## wheel physics. Player driving is unaffected. Takes effect on the next tick.
static var follow_road_path: bool = true

## Automatic driving speed cap in km/h; bends and terminal braking may lower it.
@export var cruise_speed_kmh: float = 30.0

## Maximum front-wheel angle in radians, shared by both input sources.
@export var steering_limit: float = 0.55

## Steering response in radians per second.
@export var steering_rate: float = 1.8

## Assumed deceleration in m/s² used to calculate the automatic stopping distance.
@export var braking_deceleration: float = 3.0

## Target lateral acceleration in m/s² when planning automatic corner speed.
@export_range(0.5, 5.0, 0.1) var cornering_lateral_acceleration: float = 1.5

## Maximum horizontal distance in metres from which automatic driving may resume.
@export var route_recovery_distance: float = 6.0

## Gameplay radius in metres, deliberately independent of physical steering limits.
@export_range(0.25, 5.0, 0.05) var automatic_uturn_radius: float = 1.25

## Scripted U-turn speed in metres per second.
@export_range(0.25, 4.0, 0.05) var automatic_uturn_speed: float = 1.5

## Acceleration in m/s² while following the road curve; braking uses braking_deceleration.
@export_range(0.1, 5.0, 0.1) var path_acceleration: float = 1.5

## Distance in metres over which fixed-path following eases from the takeover pose.
const PATH_BLEND_METRES: float = 3.0

## Scripted obstacle checks run this far above the body. Authored chassis boxes
## reach down to the road surface the wheels hold them above, so an unraised
## check would report the supporting road itself as an obstruction.
const SCRIPTED_GROUND_CLEARANCE: float = 0.1

var vehicle_obj: VehicleData
var inventory_component: InventoryContainer

## Editable itinerary data, separate from the currently executed driving geometry.
@export var route_plan: RoadRoutePlan = RoadRoutePlan.new()
var plan_execution := preload("res://game/gamescripts/services/routing/road_plan_executor.gd").new()

## Temporary driving geometry and progress, not a service itinerary or pathfinder.
var route := RoadVehicleRoute.new()
var player_driving: bool = false
var camera: Camera3D
var wheelbase: float = 2.5
var dimensions_metres: Vector3
var maximum_speed_kmh: float = 50.0
var motor_power_watts: float = 25000.0
var _arrived: bool = false
var _uturn := RoadVehicleUTurn.new()

# Scripted motion: shared kinematic hold for U-turns and fixed-path following.
var _scripted: bool = false
var _scripted_velocity: Vector3
var _pre_script_freeze: bool
var _pre_script_freeze_mode: RigidBody3D.FreezeMode

# Fixed-path following progress; route.progress remains the position on the curve.
var _path_active: bool = false
var _path_curve: Curve3D
var _path_speed: float = 0.0
var _path_height: float = 0.0
var _path_entry: Transform3D
var _path_entry_progress: float = 0.0

#region Construction
## Construct before tree insertion so callers can assign a path and spawn pose.
static func of(type_key: String) -> RoadVehicle3D:
	return RoadVehicleFactory.create(type_key)

func get_inventory() -> GoodsInventory:
	return inventory_component.get_inventory() if is_instance_valid(inventory_component) else null
#endregion

#region Driver handoff
## Atomically replace a driving path; itinerary/pathfinding decisions stay outside
## this movement controller. This legacy whole-road API also supports previews.
func set_route(paths: Array[Path3D], backwards: bool = false) -> bool:
	if not route.assign(paths, backwards):
		return false
	_uturn.reset()
	# The physical driver takes the body back now, keeping its velocity. With
	# fixed-path following, the body stays held and eases onto the new curve.
	if not follow_road_path:
		_release_scripted(true)
	if is_inside_tree():
		route.progress = route.curve.get_closest_offset(global_position)
	_arrived = false
	return true

## Replace the driving path with partial-road segments chosen by the itinerary
## executor, and start driving it. The arrival latch is reset for the new path.
## Returns false, keeping the current path, if the segments do not form one.
func assign_path_segments(segments: Array[Dictionary], end_trim: float = 0.0) -> bool:
	if not route.assign_segments(segments, end_trim):
		return false
	_arrived = false
	return true

## Stop where the vehicle stands and drop its driving path, but keep a fixed-path
## body frozen. The executor parks this way between movements of one itinerary
## (servicing a stop, waiting at a road end before a U-turn), so a held body
## does not drop onto its suspension in between. An active turn is abandoned.
## A body driven by wheel physics just gets the parking brake.
func park() -> void:
	_uturn.reset()
	_reset_path_follow()
	_scripted_velocity = Vector3.ZERO
	_drop_route()

## Stop and drop the driving path, handing any frozen body back to wheel physics
## with zero velocity. Used when automatic driving ends: plan stops, completion,
## a vehicle that is no longer assigned a path.
func clear_route() -> void:
	_uturn.reset()
	_release_scripted(false)
	_drop_route()

## Shared by park() and clear_route(): forget the path and apply the parking brake.
func _drop_route() -> void:
	route = RoadVehicleRoute.new()
	_arrived = false
	engine_force = 0.0
	brake = mass * 0.04

## True once the vehicle has stopped at the end of its driving path. Whichever
## driver owns movement latches this; assigning a new path resets it.
func has_arrived() -> bool:
	return _arrived

## Latch arrival without driving. The executor uses this when it parks a vehicle
## already standing at the road end where its U-turn starts.
func mark_arrived() -> void:
	_arrived = true

## Change only the input source; retain pose, velocity and automatic path progress.
func set_player_driving(enabled: bool) -> void:
	player_driving = enabled
	if enabled:
		# The player takes over mid-manoeuvre: drop the turn and hand the body
		# back to wheel physics with its current scripted velocity.
		_uturn.reset()
		_release_scripted(true)
		_arrived = false
	# Clear the previous driver's force immediately, preserving physical motion.
	engine_force = 0.0
	brake = 0.0
	sleeping = false

## Velocity of whichever driver owns the body: physics, or the scripted pose.
func current_velocity() -> Vector3:
	return _scripted_velocity if _scripted else linear_velocity

func signed_speed_mps() -> float:
	return current_velocity().dot(global_basis.z.normalized())

func is_following_fixed_path() -> bool:
	return _path_active
#endregion

#region Shared driving inputs
func _physics_process(delta: float) -> void:
	# One driver owns movement per tick: manual input, an active turn, fixed-path
	# following or normal route physics. The executor can enter a turn, so check
	# again after its tick.
	if player_driving:
		_drive_player(delta)
		return
	if is_automatic_uturning():
		_drive_automatic_uturn(delta)
		return
	plan_execution.tick(self)
	if is_automatic_uturning():
		_drive_automatic_uturn(delta)
	elif follow_road_path:
		_drive_route_fixed(delta)
	else:
		_drive_route(delta)

func _drive_player(delta: float) -> void:
	if UiState.current_diag != null or UiState.movement_blocked:
		apply_driver_input(0.0, 0.0, 1.0, delta)
		return
	# VehicleBody3D faces +Z, so the driver's right is local -X.
	var turn: float = Input.get_axis("move_right", "move_left")
	var pedal: float = Input.get_axis("move_backward", "move_forward")
	var braking: float = 1.0 if Input.is_physical_key_pressed(KEY_SPACE) else 0.0
	apply_driver_input(turn, pedal, braking, delta)

## Steering and pedal requests are normalized. S first brakes forward motion,
## then reverses once stopped; W does the corresponding thing when reversing.
func apply_driver_input(turn: float, pedal: float, service_brake: float, delta: float) -> void:
	var speed: float = signed_speed_mps()
	steering = move_toward(steering, clampf(turn, -1.0, 1.0) * steering_limit, steering_rate * delta)
	var braking: float = clampf(service_brake, 0.0, 1.0)
	if pedal * speed < -0.3:
		braking = maxf(braking, absf(pedal))
		pedal = 0.0
	if absf(speed) * 3.6 >= (maximum_speed_kmh if pedal >= 0.0 else 15.0):
		pedal = 0.0
	engine_force = clampf(pedal, -1.0, 1.0) * _available_engine_force(speed) if braking < 0.01 else 0.0
	brake = braking * mass * 0.04

## Engine force is per traction wheel. Split power between two rear wheels,
## cap starting traction and approximate constant power above walking speed.
func _available_engine_force(speed: float) -> float:
	return minf(mass * 1.5, motor_power_watts / maxf(absf(speed), 2.0) * 0.5)
#endregion

#region Scripted motion
## Kinematic freeze stops the wheel solver from fighting a scripted pose. Holding
## is idempotent, so fixed-path following can pass straight into a U-turn and back
## while the original freeze configuration is recorded only once.
func _hold_scripted() -> void:
	if _scripted:
		return
	_pre_script_freeze = freeze
	_pre_script_freeze_mode = freeze_mode
	_scripted = true
	_scripted_velocity = Vector3.ZERO
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	engine_force = 0
	brake = 0
	steering = 0

## Restore exactly the previous freeze configuration. Manual takeover keeps the
## scripted tangent velocity; stops discard it. Safe to call when not held.
func _release_scripted(keep_velocity: bool) -> void:
	if not _scripted:
		return
	var velocity: Vector3 = _scripted_velocity if keep_velocity else Vector3.ZERO
	_scripted = false
	_scripted_velocity = Vector3.ZERO
	_reset_path_follow()
	freeze = _pre_script_freeze
	freeze_mode = _pre_script_freeze_mode
	linear_velocity = velocity if not freeze else Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false

## Sweep using the next orientation too, so a wide body cannot rotate through
## nearby obstacles. Collisions stay enabled throughout scripted motion.
func _scripted_motion_is_clear(pose: Transform3D) -> bool:
	# Explicit space queries still work while wheel/body simulation is frozen.
	# Check the next rotated footprint, then sweep its translation; ignore self.
	# Both run slightly raised so the road under the wheels is not an obstacle.
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var lift := Vector3.UP * SCRIPTED_GROUND_CLEARANCE
	for child: Node in get_children():
		if not child is CollisionShape3D or child.disabled or child.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = child.shape
		query.exclude = [get_rid()]
		query.collision_mask = collision_mask
		query.margin = 0.02
		query.transform = Transform3D(pose.basis, pose.origin + lift) * child.transform
		if not space.intersect_shape(query, 1).is_empty():
			return false
		query.transform = Transform3D(pose.basis, global_position + lift) * child.transform
		query.motion = pose.origin - global_position
		if space.cast_motion(query)[0] < 1.0:
			return false
	return true

## Commit a checked pose, deriving the velocity reported while frozen.
func _move_scripted(pose: Transform3D, delta: float) -> bool:
	if not _scripted_motion_is_clear(pose):
		_scripted_velocity = Vector3.ZERO
		return false
	_scripted_velocity = (pose.origin - global_position) / maxf(delta, 0.001)
	global_transform = pose
	return true
#endregion

#region Automatic endpoint U-turns
func is_automatic_uturning() -> bool:
	return _uturn.active

## Only the automatic route executor requests this, after braking at a road end.
func begin_automatic_uturn(path: Path3D, endpoint: float) -> bool:
	if _uturn.active or player_driving or current_velocity().length() > 0.2 or not is_finite(automatic_uturn_speed) or automatic_uturn_speed <= 0:
		return false
	if not is_instance_valid(path) or not path.is_inside_tree() or path.curve == null:
		return false
	var end: Vector3 = path.to_global(path.curve.sample_baked(endpoint))
	if global_position.distance_to(end) > dimensions_metres.z * 0.55 + 1.5:
		return false
	if not _uturn.build(global_transform, path, endpoint, automatic_uturn_radius):
		return false
	_hold_scripted()
	_reset_path_follow()
	_scripted_velocity = Vector3.ZERO
	_arrived = false
	return true

func _drive_automatic_uturn(delta: float) -> void:
	if not _uturn.is_valid():
		plan_execution.stop(self, "U-turn road is no longer available.")
		return
	var next: float = minf(_uturn.progress + automatic_uturn_speed * delta, _uturn.curve.get_baked_length())
	if not _move_scripted(_uturn.sample(next), delta):
		plan_execution.status = "U-turn blocked: waiting for clearance."
		return
	_uturn.progress = next
	plan_execution.status = "Turning at road end"
	if next >= _uturn.curve.get_baked_length():
		_uturn.reset()
		# The physical driver takes over with the curve's exit velocity. With
		# fixed-path following, the body stays held and the next segment
		# continues at that speed without dropping onto the suspension.
		if not follow_road_path:
			_release_scripted(true)

#endregion

#region Fixed-path driving
## Place the body on the route curve, using the same bend and stop speed planning
## as the physical driver. Arrival keeps the body held and stationary, so stops
## and U-turns follow without a physics handoff; clear_route() releases it.
func _drive_route_fixed(delta: float) -> void:
	# No route while held means the executor parked us (park()); stay put until
	# it assigns the next path, or clear_route() hands the body back to physics.
	if not route.is_valid() or _arrived:
		if _scripted:
			_scripted_velocity = Vector3.ZERO
		else:
			apply_driver_input(0.0, 0.0, 1.0, delta)
		return
	# A new curve (replanned segment, legacy set_route) restarts the entry blend.
	if (not _path_active or _path_curve != route.curve) and not _begin_path_follow():
		# Unsettled or too far off the curve: the physical driver recovers first.
		_drive_route(delta)
		return
	var length: float = route.curve.get_baked_length()
	var distance_left: float = maxf(0.0, length - route.progress - dimensions_metres.z * 0.55)
	# Heading error is always zero on the curve; only bends and the stop limit speed.
	var desired: float = _desired_route_speed(0.0, distance_left)
	var rate: float = path_acceleration if desired > _path_speed else braking_deceleration
	_path_speed = move_toward(_path_speed, desired, rate * delta)
	var next: float = minf(route.progress + _path_speed * delta, length)
	if not _move_scripted(_route_pose(next), delta):
		_path_speed = 0.0
		if plan_execution.running:
			plan_execution.status = "Blocked: waiting for clearance."
		return
	route.progress = next
	if plan_execution.running:
		plan_execution.status = plan_execution.driving_status()
	if desired < 0.1 and _path_speed < 0.1:
		_path_speed = 0.0
		_scripted_velocity = Vector3.ZERO
		_arrived = true
		route_finished.emit()

## Start from a settled body (or one already held after a U-turn) near the curve.
## Its current height above the centreline is kept for the whole path.
func _begin_path_follow() -> bool:
	if not _scripted and not _is_settled():
		return false
	route.update_progress(global_position)
	if not _is_near_route():
		return false
	var speed: float = maxf(0.0, signed_speed_mps())
	_hold_scripted()
	_path_speed = speed
	_path_height = global_position.y - route.curve.sample_baked(route.progress).y
	_path_entry = global_transform
	_path_entry_progress = route.progress
	_path_curve = route.curve
	_path_active = true
	return true

## Heading from a ±0.5 m chord, so slopes pitch the body. Ease in from the
## takeover pose so starting a few metres off the centreline does not snap.
func _route_pose(offset: float) -> Transform3D:
	var curve: Curve3D = route.curve
	var length: float = curve.get_baked_length()
	var behind: Vector3 = curve.sample_baked(maxf(0.0, offset - 0.5))
	var ahead: Vector3 = curve.sample_baked(minf(length, offset + 0.5))
	var target := Transform3D(Basis.looking_at((ahead - behind).normalized(), Vector3.UP, true),
		curve.sample_baked(offset) + Vector3.UP * _path_height)
	var blend: float = clampf((offset - _path_entry_progress) / PATH_BLEND_METRES, 0.0, 1.0)
	return _path_entry.interpolate_with(target, blend)

## Wheels resting on the road; a freshly spawned or bouncing body settles first.
func _is_settled() -> bool:
	var contacts: int = 0
	for child: Node in get_children():
		if child is VehicleWheel3D and child.is_in_contact():
			contacts += 1
	return contacts >= 3 and absf(linear_velocity.y) < 0.5

func _reset_path_follow() -> void:
	_path_active = false
	_path_curve = null
	_path_speed = 0.0
#endregion

#region Automatic driving

## Execute geometry supplied by a planner; do not choose destinations or transfer goods.
func _drive_route(delta: float) -> void:
	# Turning fixed-path following off at runtime hands the body back to physics.
	_release_scripted(true)
	if not route.is_valid():
		apply_driver_input(0.0, 0.0, 1.0, delta)
		return
	route.update_progress(global_position)
	if not _is_near_route():
		if plan_execution.running:
			plan_execution.status = "Off route: drive back near the assigned path to resume."
		apply_driver_input(0.0, 0.0, 1.0, delta)
		return
	var speed: float = signed_speed_mps()
	# A long wheelbase needs to start steering earlier, even at corner speed.
	var lookahead: float = maxf(maxf(4.0, wheelbase * 1.6), absf(speed) * 0.8)
	var target: Vector3 = to_local(route.sample_ahead(lookahead))
	var angle: float = atan2(target.x, target.z)
	var stop_margin: float = dimensions_metres.z * 0.55
	var distance_left: float = maxf(0.0, route.remaining() - stop_margin)
	if absf(angle) > PI * 0.65 and distance_left > 1.0:
		if plan_execution.running:
			plan_execution.status = "Turn the vehicle toward the route manually to resume."
		apply_driver_input(0.0, 0.0, 1.0, delta)
		return
	if plan_execution.running:
		plan_execution.status = plan_execution.driving_status()
	var turn: float = atan2(2.0 * wheelbase * sin(angle), lookahead) / steering_limit
	_apply_route_speed(turn, _desired_route_speed(angle, distance_left), speed, delta)

## Recovery uses horizontal distance because suspension determines the body's height.
func _is_near_route() -> bool:
	var nearest: Vector3 = route.curve.sample_baked(route.progress)
	var horizontal_error := Vector2(global_position.x - nearest.x, global_position.z - nearest.z)
	return horizontal_error.length() <= route_recovery_distance

## Plan for bends beyond the steering lookahead, then apply heading and stop limits.
func _desired_route_speed(angle: float, distance_left: float) -> float:
	if distance_left < 0.3:
		return 0.0
	var cruise_speed: float = minf(cruise_speed_kmh, maximum_speed_kmh) / 3.6
	var stop_speed: float = sqrt(2.0 * braking_deceleration * distance_left)
	# Allow for brake response and leave grip available for steering.
	var approach_deceleration: float = maxf(0.1, braking_deceleration * 0.5)
	var bend_speed: float = route.speed_before_bends(cruise_speed, approach_deceleration, cornering_lateral_acceleration)
	return minf(bend_speed, minf(cruise_speed / (1.0 + absf(angle) * 2.0), stop_speed))

## Convert target speed to pedals and latch arrival once for this assigned path.
func _apply_route_speed(turn: float, desired_speed: float, speed: float, delta: float) -> void:
	var pedal: float = clampf((desired_speed - speed) * 0.7, 0.0, 1.0)
	var braking: float = clampf((speed - desired_speed) * 0.5, 0.0, 1.0)
	if desired_speed < 0.1:
		braking = 1.0
		if absf(speed) < 0.2 and not _arrived:
			_arrived = true
			route_finished.emit()
	apply_driver_input(turn, pedal, braking, delta)
#endregion


func uses_road(road: RoadWay3D) -> bool:
	var path: Path3D = road.get_path_3d()
	if path in route._paths or _uturn.source == path:
		return true
	if not is_inside_tree() or not path.is_inside_tree():
		return false
	# A manually driven or parked vehicle may have no driving route.
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, global_position - Vector3.UP * 2.0, 1)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var collider: Node = hit.get("collider")
	return collider != null and road.is_ancestor_of(collider)
