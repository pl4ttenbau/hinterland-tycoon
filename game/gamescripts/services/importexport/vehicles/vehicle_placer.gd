@icon("res://assets/icons/icon_locomotive_white.png")
class_name VehiclePlacer extends Node

const ROUTE_DIALOG = preload("res://game/gamescripts/ui/dialogs/road_route/road_route_dialog.gd")

@export var rail_containers: Array[RailTrack3D]
@export var trains: Array[Train3D] = []
@export var start_vehicles_spawned: bool = false

@export var player_train: Train3D

var road_vehicles: Array[RoadVehicle3D] = []
var player_road_vehicle: RoadVehicle3D
## User-facing reason for a rejected depot spawn, read by the selection dialog.
var last_road_spawn_error: String = ""
const ROAD_DEPOT_SPAWN_DISTANCE: float = 10.0
var _walking_process_mode: int
var _walking_collision_layer: int
var _walking_collision_mask: int

#region Initialization
## Called by the circular menu only for the currently occupied road vehicle.
func open_road_route_dialog() -> bool:
	if not is_instance_valid(player_road_vehicle) or UiState.current_diag != null:
		return false
	get_tree().root.add_child(ROUTE_DIALOG.create(player_road_vehicle))
	return true

func _check_rails_and_terrain() -> bool:
	if !GlobalState:
		push_warning("Cannot save vehicle in scene: Globals not found")
		return false
	if !rail_containers:
		push_warning("RailContainers not loaded; aboring vehicle creation")
		return false
	return true
	
func load_vehicles():
	var all_loaded: bool = self._check_rails_and_terrain()
	if  !all_loaded: return
	Loggie.info("Globals & rails found: initializing vehicles...")
	self.start_vehicles_spawned = true
#endregion

#region Vehicle Spawning
## Ordered road IDs form a continuous route; no arbitrary branch is chosen at
## intersections. The first road's direction can be reversed explicitly.
func spawn_road_vehicle(type_key: String, road_numbers: Array[int], backwards: bool = false, start_distance: float = -1.0) -> RoadVehicle3D:
	var paths: Array[Path3D] = _resolve_road_paths(road_numbers)
	if paths.is_empty():
		return null
	var vehicle := RoadVehicle3D.of(type_key)
	if vehicle == null:
		return null
	if not vehicle.set_route(paths, backwards):
		vehicle.free()
		return null
	if start_distance > vehicle.route.curve.get_baked_length():
		vehicle.free()
		return null
	add_child(vehicle)
	_place_road_vehicle_at_path_start(vehicle, start_distance)
	road_vehicles.append(vehicle)
	vehicle.tree_exiting.connect(func(): road_vehicles.erase(vehicle), CONNECT_ONE_SHOT)
	return vehicle

## Depot cars are parked until the player enters or a driving path is assigned.
## Distance is measured along the road, not as a straight offset from its node.
func spawn_road_vehicle_at_depot(type_key: String, depot: RoadDepotData) -> RoadVehicle3D:
	last_road_spawn_error = ""
	if depot == null or depot.road_pos not in ["START", "END"]:
		return _reject_road_depot_spawn("This depot has no valid road endpoint.")
	var paths: Array[Path3D] = _resolve_road_paths([depot.road_num])
	if paths.is_empty():
		return _reject_road_depot_spawn("The depot's road is unavailable.")
	var vehicle: RoadVehicle3D = spawn_road_vehicle(
		type_key, [depot.road_num], depot.road_pos == "END", ROAD_DEPOT_SPAWN_DISTANCE
	)
	if vehicle == null:
		return _reject_road_depot_spawn("Could not spawn: the road must extend at least 10 m from the depot.")
	if _is_road_spawn_occupied(vehicle):
		vehicle.free()
		return _reject_road_depot_spawn("Move the vehicle at the spawn point before spawning another.")
	vehicle.clear_route()
	return vehicle

## Include pending spawns before the physics server has registered their shapes.
func _is_road_spawn_occupied(candidate: RoadVehicle3D) -> bool:
	for other: RoadVehicle3D in road_vehicles:
		if other == candidate or not is_instance_valid(other):
			continue
		var clearance: float = (candidate.dimensions_metres.z + other.dimensions_metres.z) * 0.5 + 0.5
		if candidate.global_position.distance_to(other.global_position) < clearance:
			return true
	return false

func _reject_road_depot_spawn(message: String) -> RoadVehicle3D:
	last_road_spawn_error = message
	return null

## Resolve every ID before constructing a vehicle; missing roads reject the request.
func _resolve_road_paths(road_numbers: Array[int]) -> Array[Path3D]:
	if Managers.roads == null or road_numbers.is_empty():
		return []
	var paths: Array[Path3D] = []
	for road_number: int in road_numbers:
		var road: RoadWay3D = Managers.roads.storage.get_container_by_num(road_number)
		if road == null:
			return []
		paths.append(road.get_path_3d())
	return paths

## Initial placement is the only spawn teleport. Physics owns movement afterward.
## Start far enough along the curve for the rear axle and above its surface.
func _place_road_vehicle_at_path_start(vehicle: RoadVehicle3D, start_distance: float = -1.0) -> void:
	var curve: Curve3D = vehicle.route.curve
	var offset: float = start_distance if start_distance >= 0.0 else minf(vehicle.wheelbase, curve.get_baked_length() * 0.25)
	var pos: Vector3 = curve.sample_baked(offset)
	var forward: Vector3 = curve.sample_baked(offset + 0.1) - curve.sample_baked(offset - 0.1)
	vehicle.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP, true), pos + Vector3.UP * 0.8)
	vehicle.route.progress = offset

func spawn_train(veh_type_key: String, start_pos: VehicleStartPos) -> Train3D:
	var train3d := Train3D.of(veh_type_key, start_pos)
	self.add_child(train3d)
	# assign name and num
	train3d.name = "Train_%d" % train3d.num
	# add to own array and as child
	GlobalState.trains.append(train3d)
	self.trains.append(train3d)
	return train3d
#endregion

#region Enter & Exit
func enter_vehicle(veh3d: Node3D):
	if veh3d is RoadVehicle3D:
		enter_road_vehicle(veh3d)
		return
	if not veh3d is Vehicle3D or veh3d.train3d == null:
		return
	if player_road_vehicle != null:
		exit_road_vehicle()
	self.player_train = veh3d.train3d
	self.activate_cam(self.player_train.get_cam())
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	SignalBus.player_entered_train.emit(self.player_train)

## Transfer input/camera ownership without changing the vehicle's physical motion.
func enter_road_vehicle(vehicle: RoadVehicle3D) -> void:
	if player_road_vehicle == vehicle or not is_instance_valid(GlobalState.player):
		return
	if player_road_vehicle != null:
		exit_road_vehicle()
	if player_train != null:
		exit_train()
	_suspend_walking_player(GlobalState.player.player_parent)
	player_road_vehicle = vehicle
	vehicle.set_player_driving(true)
	vehicle.tree_exiting.connect(exit_road_vehicle, CONNECT_ONE_SHOT)
	activate_cam(vehicle.camera)
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	SignalBus.player_entered_road_vehicle.emit(vehicle)

## Preserve the exact settings so leaving also works for a custom walking setup.
func _suspend_walking_player(player: BasicFpsPlayer) -> void:
	_walking_process_mode = player.process_mode
	_walking_collision_layer = player.collision_layer
	_walking_collision_mask = player.collision_mask
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.collision_layer = 0
	player.collision_mask = 0
	player.velocity = Vector3.ZERO

## Also called when an occupied car leaves the tree; restoration must be shared.
func exit_road_vehicle() -> void:
	var vehicle: RoadVehicle3D = player_road_vehicle
	if not is_instance_valid(vehicle):
		return
	vehicle.set_player_driving(false)
	if vehicle.tree_exiting.is_connected(exit_road_vehicle):
		vehicle.tree_exiting.disconnect(exit_road_vehicle)
	player_road_vehicle = null
	if is_instance_valid(GlobalState.player):
		_restore_walking_player(GlobalState.player.player_parent, vehicle)
		activate_cam(GlobalState.player.cam)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	SignalBus.player_exited_road_vehicle.emit()

## Use the body's low origin with a small step up beside the door.
func _restore_walking_player(player: BasicFpsPlayer, vehicle: RoadVehicle3D) -> void:
	player.global_position = vehicle.global_position + vehicle.global_basis.x.normalized() * 3.0 + Vector3.UP * 0.5
	player.process_mode = _walking_process_mode as Node.ProcessMode
	player.collision_layer = _walking_collision_layer
	player.collision_mask = _walking_collision_mask

func _exit_tree() -> void:
	if is_instance_valid(player_road_vehicle):
		exit_road_vehicle()
	
func exit_train():
	SignalBus.player_exited_train.emit()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	self.activate_cam(GlobalState.player.cam)
	self.player_train = null

func activate_cam(cam: Camera3D):
	cam.make_current()
	GlobalState.active_cam = cam
	var terr3d: Terrain3D = GlobalState.world_container.terrain if is_instance_valid(GlobalState.world_container) else null
	if terr3d:
		terr3d.set_camera(cam)
	else:
		Loggie.warn("Terrain3D cannot be found for camera change")
#endregion

#region Callbacks
func _on_rails_rails_spawned(containers: Array[RailTrack3D]) -> void:
	Loggie.info("Rails spawned; initializing vehicles ...")
	self.rail_containers = containers
	load_vehicles()
#endregion
