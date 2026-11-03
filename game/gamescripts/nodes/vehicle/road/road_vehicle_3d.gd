## One physical vehicle: the player supplies free steering, otherwise the route
## supplies steering and speed requests. Automatic endpoint U-turns temporarily
## use a collision-checked curve; manual driving always retains wheel physics.
class_name RoadVehicle3D extends VehicleBody3D

## Emitted once per assigned driving path after its terminal stop.
signal route_finished()

## Automatic driving speed cap in km/h; bends and terminal braking may lower it.
@export var cruise_speed_kmh: float = 30.0
## Maximum front-wheel angle in radians, shared by both input sources.
@export var steering_limit: float = 0.55
## Steering response in radians per second.
@export var steering_rate: float = 1.8
## Assumed deceleration in m/s² used to calculate the automatic stopping distance.
@export var braking_deceleration: float = 3.0
## Maximum horizontal distance in metres from which automatic driving may resume.
@export var route_recovery_distance: float = 6.0
## Gameplay radius in metres, deliberately independent of physical steering limits.
@export_range(0.25, 5.0, 0.05) var automatic_uturn_radius: float = 1.25
## Scripted U-turn speed in metres per second.
@export_range(0.25, 4.0, 0.05) var automatic_uturn_speed: float = 1.5

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
var maximum_speed_kmh: float = 50.0
var motor_power_watts: float = 25000.0
var _arrived: bool = false
var _uturn := RoadVehicleUTurn.new()
var _turn_previous_freeze: bool
var _turn_previous_freeze_mode: RigidBody3D.FreezeMode
var _turn_velocity: Vector3

#region Construction
## Construct before tree insertion so callers can assign a path and spawn pose.
## Generic wheel placement can later be replaced without changing either driver.
static func of(type_key: String) -> RoadVehicle3D:
	if GameTypes.ensure_initialized() != OK:
		return null
	var type: RoadVehicleTypeData = GameTypes.get_veh_type(type_key) as RoadVehicleTypeData
	if type == null:
		push_warning("Cannot spawn road vehicle type: %s" % type_key)
		return null
	var body := RoadVehicle3D.new()
	body._configure_catalog_values(type)
	body._configure_physics()
	body._build_vehicle(type)
	return body

## Convert catalog tonnes/kW to physics kilograms/watts. Unknown specifications
## use prototype defaults without changing the catalog's nullable values.
func _configure_catalog_values(type: RoadVehicleTypeData) -> void:
	vehicle_obj = VehicleData.of(type.key)
	name = "RoadVehicle_%d" % vehicle_obj.num
	mass = float(type.mass_tonnes) * 1000.0 if type.mass_tonnes != null else 1000.0
	maximum_speed_kmh = float(type.max_speed_kmh) if type.max_speed_kmh != null else 50.0
	motor_power_watts = float(type.motor_power_kw) * 1000.0 if type.motor_power_kw != null else 25000.0

func _configure_physics() -> void:
	continuous_cd = true
	# The tall chassis box must not lift the centre of mass above the wheels.
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO
	collision_layer = 2
	collision_mask = 15

## Share estimated dimensions between chassis, suspension, visual and camera.
func _build_vehicle(type: RoadVehicleTypeData) -> void:
	var length: float = type.length_metres
	var width: float = float(type.width_metres) if type.width_metres != null else 1.8
	var height: float = float(type.height_metres) if type.height_metres != null else 1.8
	wheelbase = length * 0.6
	var radius: float = clampf(width * 0.2, 0.28, 0.45)
	var ride_height: float = radius + 0.08
	_add_chassis(Vector3(width, height, length), ride_height)
	_add_wheels(width, radius)
	_add_model(type, ride_height)
	_add_camera(length, height)
	_add_inventory(type)

## A regular component supplies stock/capacity without changing the physics body's base class.
func _add_inventory(type: RoadVehicleTypeData) -> void:
	inventory_component = InventoryContainer.new()
	inventory_component.name = "Inventory"
	inventory_component.display_name = "%s #%d" % [type.display_name, vehicle_obj.num]
	inventory_component.capacity_override = float(type.capacity.amount) if type.capacity != null else 0.0
	if type.capacity != null:
		inventory_component.accepted_categories.append(type.capacity.goods_cat)
	add_child(inventory_component)
	inventory_component.get_inventory()

func get_inventory() -> GoodsInventory:
	return inventory_component.get_inventory() if is_instance_valid(inventory_component) else null

## Dimensions are width/height/length in metres; the body origin stays low.
func _add_chassis(dimensions: Vector3, ride_height: float) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions * Vector3(0.85, 0.65, 0.9)
	shape.shape = box
	shape.position.y = dimensions.y * 0.65 - ride_height
	add_child(shape)

func _add_wheels(width: float, radius: float) -> void:
	for axle: int in [-1, 1]:
		for side: int in [-1, 1]:
			add_child(_create_wheel(axle, side, width, radius))

## +Z is the front axle and +X the driver's left. These shared suspension values
## are handling assumptions; front wheels steer and rear wheels provide traction.
func _create_wheel(axle: int, side: int, width: float, radius: float) -> VehicleWheel3D:
	var wheel := VehicleWheel3D.new()
	wheel.name = "%s%s" % ["Front" if axle == 1 else "Rear", "Left" if side == 1 else "Right"]
	wheel.position = Vector3(side * width * 0.4, 0.1, axle * wheelbase * 0.5)
	wheel.use_as_steering = axle == 1
	wheel.use_as_traction = axle == -1
	wheel.wheel_radius = radius
	wheel.wheel_rest_length = 0.18
	wheel.suspension_travel = 0.2
	wheel.suspension_stiffness = 40.0
	wheel.suspension_max_force = mass * 10.0
	wheel.damping_compression = 0.5
	wheel.damping_relaxation = 0.8
	return wheel

## Catalog scenes also serve as decoration or train-style views. Keep only their
## visuals so the oldtimer's Vehicle3D script and static collider never run.
func _add_model(type: RoadVehicleTypeData, ride_height: float) -> void:
	var model: Node3D = load(type.model_scene_path).instantiate()
	model.set_script(null)
	_strip_model_physics(model)
	if type.key in ["gaz_aa_truck", "trabant_601_green"]:
		model.rotation.y = PI * 0.5
	model.position.y = -ride_height
	add_child(model)

func _add_camera(length: float, height: float) -> void:
	camera = Camera3D.new()
	camera.name = "DrivingCamera"
	camera.position = Vector3(0, height + 2.0, -length - 4.0)
	camera.rotation.y = PI
	camera.rotation.x = -0.18
	camera.set_meta("cam_name", &"CAM_ROAD_VEHICLE")
	add_child(camera)

static func _strip_model_physics(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CollisionObject3D:
			child.free()
		else:
			_strip_model_physics(child)
	if node is GeometryInstance3D:
		node.layers = 64
#endregion

#region Driver handoff
## Atomically replace a driving path; itinerary/pathfinding decisions stay outside
## this movement controller. This legacy whole-road API also supports previews.
func set_route(paths: Array[Path3D], backwards: bool = false) -> bool:
	if not route.assign(paths, backwards):
		return false
	_end_automatic_uturn(true)
	if is_inside_tree():
		route.progress = route.curve.get_closest_offset(global_position)
	_arrived = false
	return true

## Remove automatic driving requests without changing the body's physical state.
func clear_route() -> void:
	_end_automatic_uturn(false)
	route = RoadVehicleRoute.new()
	_arrived = false
	engine_force = 0.0
	brake = mass * 0.04

## Change only the input source; retain pose, velocity and automatic path progress.
func set_player_driving(enabled: bool) -> void:
	player_driving = enabled
	if enabled:
		_end_automatic_uturn(true)
		_arrived = false
	# Clear the previous driver's force immediately, preserving physical motion.
	engine_force = 0.0
	brake = 0.0
	sleeping = false

func signed_speed_mps() -> float:
	return linear_velocity.dot(global_basis.z.normalized())
#endregion

#region Shared driving inputs
func _physics_process(delta: float) -> void:
	# One driver owns movement per tick: manual input, an active turn, or normal
	# route physics. The executor can enter a turn, so check again after its tick.
	if player_driving:
		_drive_player(delta)
	else:
		if is_automatic_uturning():
			_drive_automatic_uturn(delta)
			return
		plan_execution.tick(self)
		if is_automatic_uturning():
			_drive_automatic_uturn(delta)
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

#region Automatic endpoint U-turns
func is_automatic_uturning() -> bool:
	return _uturn.active

## Only the automatic route executor requests this, after braking at a road end.
## Kinematic freeze prevents the wheel solver from fighting the scripted curve.
func begin_automatic_uturn(path: Path3D, endpoint: float) -> bool:
	if _uturn.active or player_driving or linear_velocity.length() > 0.2 or not is_finite(automatic_uturn_speed) or automatic_uturn_speed <= 0:
		return false
	if not is_instance_valid(path) or not path.is_inside_tree() or path.curve == null:
		return false
	var end: Vector3 = path.to_global(path.curve.sample_baked(endpoint))
	if global_position.distance_to(end) > vehicle_obj.veh_type.length_metres * 0.55 + 1.5:
		return false
	if not _uturn.build(global_transform, path, endpoint, automatic_uturn_radius):
		return false
	_turn_previous_freeze = freeze
	_turn_previous_freeze_mode = freeze_mode
	_turn_velocity = Vector3.ZERO
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	engine_force = 0
	brake = 0
	steering = 0
	_arrived = false
	return true

func _drive_automatic_uturn(delta: float) -> void:
	if not _uturn.is_valid():
		plan_execution.stop(self, "U-turn road is no longer available.")
		return
	var next: float = minf(_uturn.progress + automatic_uturn_speed * delta, _uturn.curve.get_baked_length())
	var pose: Transform3D = _uturn.sample(next)
	if not _uturn_motion_is_clear(pose):
		_turn_velocity = Vector3.ZERO
		plan_execution.status = "U-turn blocked: waiting for clearance."
		return
	_turn_velocity = (pose.origin - global_position) / maxf(delta, 0.001)
	global_transform = pose
	_uturn.progress = next
	plan_execution.status = "Turning at road end"
	if next >= _uturn.curve.get_baked_length():
		_end_automatic_uturn(true)

## Sweep using the next orientation too, so a wide body cannot rotate through
## nearby obstacles. Collisions stay enabled throughout the assisted manoeuvre.
func _uturn_motion_is_clear(pose: Transform3D) -> bool:
	# Explicit space queries still work while wheel/body simulation is frozen.
	# Check the next rotated footprint, then sweep its translation; ignore self.
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for child: Node in get_children():
		if not child is CollisionShape3D or child.disabled or child.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = child.shape
		query.exclude = [get_rid()]
		query.collision_mask = collision_mask
		query.margin = 0.02
		query.transform = pose * child.transform
		if not space.intersect_shape(query, 1).is_empty():
			return false
		query.transform = Transform3D(pose.basis, global_position) * child.transform
		query.motion = pose.origin - global_position
		if space.cast_motion(query)[0] < 1.0:
			return false
	return true

## Manual takeover keeps the current pose and tangent velocity. Stops discard
## turn velocity. Both restore exactly the body's previous freeze configuration.
func _end_automatic_uturn(keep_velocity: bool) -> void:
	if not _uturn.active:
		return
	_uturn.active = false
	_uturn.source = null
	_uturn.curve = null
	_uturn.progress = 0
	freeze = _turn_previous_freeze
	freeze_mode = _turn_previous_freeze_mode
	linear_velocity = _turn_velocity if keep_velocity and not freeze else Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false

#endregion

#region Automatic driving

## Execute geometry supplied by a planner; do not choose destinations or transfer goods.
func _drive_route(delta: float) -> void:
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
	var lookahead: float = maxf(4.0, absf(speed) * 0.8)
	var target: Vector3 = to_local(route.sample_ahead(lookahead))
	var angle: float = atan2(target.x, target.z)
	var stop_margin: float = vehicle_obj.veh_type.length_metres * 0.55
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

## Corner caution and v² = 2ad braking lower the cruise cap before the final stop.
func _desired_route_speed(angle: float, distance_left: float) -> float:
	var desired_speed: float = minf(cruise_speed_kmh, maximum_speed_kmh) / 3.6
	desired_speed = minf(desired_speed / (1.0 + absf(angle) * 2.0), sqrt(2.0 * braking_deceleration * distance_left))
	if distance_left < 0.3:
		desired_speed = 0.0
	return desired_speed

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
