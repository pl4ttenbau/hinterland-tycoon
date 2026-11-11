extends RefCounted

## Shared integration state keeps test phases explicit without repeating setup.
## Saved globals are restored after every phase, including an aborted phase.
class DrivingFixture:
	var roads: RoadsLoader
	var manager: VehiclePlacer
	var body: RoadVehicle3D
	var outer_player: Node3D
	var player: BasicFpsPlayer
	var walking_process_mode: int
	var walking_mask: int
	var walking_layer: int
	var previous_roads: RoadsLoader
	var previous_vehicles: VehiclePlacer
	var previous_player: PlayerHead3D
	var previous_camera: Camera3D

var failures: int = 0
var passed: int = 0
var tree: SceneTree

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for frame: int in range(count):
		await tree.physics_frame

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	for test: StringName in [&"test_models", &"test_routes", &"test_driving", &"test_depot_spawning", &"test_spawn_dialog"]:
		if await call(test) != true:
			check(false, "%s aborted" % test)
	print("Road vehicle tests: %d passed, %d failures" % [passed, failures])
	return 0 if failures == 0 else 1

func test_models() -> bool:
	check(GameTypes.ensure_initialized() == OK, "Catalog initializes")
	var layouts := {
		"daimler_1911_bus": Vector4(4.01, 1.28, 1.61, 1.87),
		"ifa_w50_covered": Vector4(3.20, 0.45, 1.70, 1.78),
	}
	for key: String in ["oldtimer_car", "gaz_aa_truck", "trabant_601_green", "daimler_1911_bus", "ifa_w50_covered"]:
		var body := RoadVehicle3D.of(key)
		check(body != null and body.vehicle_obj.veh_type.key == key, "Catalog vehicle spawns as a road body")
		if body == null:
			continue
		var wheels: int = 0
		for child: Node in body.get_children():
			if child is VehicleWheel3D:
				wheels += 1
		check(wheels == 4, "Vehicle has four raycast wheels")
		check(body.mass > 500.0 and body.camera != null, "Mass and camera are configured before tree insertion")

		# The authored box supplies runtime dimensions. Check the measured axle layouts.
		var chassis := body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		check(chassis != null and chassis.shape is BoxShape3D and body.dimensions_metres.is_equal_approx(chassis.shape.size),
			"Runtime dimensions come from the mounted chassis box for %s" % key)
		var front: VehicleWheel3D = body.get_node("FrontLeft")
		var rear: VehicleWheel3D = body.get_node("RearLeft")
		var layout: Vector4 = layouts.get(key, Vector4(body.dimensions_metres.z * 0.6, 0, 0, 0))
		check(is_equal_approx(front.position.z - rear.position.z, layout.x) \
			and is_equal_approx((front.position.z + rear.position.z) * 0.5, layout.y) \
			and is_equal_approx(body.wheelbase, layout.x), "Physics and steering use the scene axle layout for %s" % key)
		if layouts.has(key):
			var front_right: VehicleWheel3D = body.get_node("FrontRight")
			var rear_right: VehicleWheel3D = body.get_node("RearRight")
			check(is_equal_approx(front.position.x - front_right.position.x, layout.z) \
				and is_equal_approx(rear.position.x - rear_right.position.x, layout.w), "%s wheels follow the two authored track widths" % key)

		tree.root.add_child(body)
		body.freeze = true
		body._physics_process(1.0 / 60.0)
		check(body.brake > 0.0 and is_zero_approx(body.engine_force), "Unassigned vehicle parks safely")
		body.free()
	return true

func test_routes() -> bool:
	var host := Node3D.new()
	host.position = Vector3(12, 5, 20)
	host.rotation.y = 0.5
	host.scale = Vector3.ONE * 1.5
	tree.root.add_child(host)
	var first := Path3D.new()
	first.curve = Curve3D.new()
	first.curve.add_point(Vector3.ZERO)
	first.curve.add_point(Vector3(0, 0, 30))
	host.add_child(first)
	var second := Path3D.new()
	second.curve = Curve3D.new()
	second.curve.add_point(Vector3(0, 0, 60))
	second.curve.add_point(Vector3(0, 0, 30))
	host.add_child(second)
	var route := RoadVehicleRoute.new()
	check(route.assign([first, second]), "Route orients an oppositely authored connecting road")
	check(is_equal_approx(route.curve.get_baked_length(), 90.0), "Route stores world-space metres under scaled parent")
	check(route.sample_ahead(90).is_equal_approx(host.to_global(Vector3(0, 0, 60))), "Connected route reaches correct world-space endpoint")
	check(route.assign([second, first]), "Route supports travel in the opposite direction")
	check(route.sample_ahead(90).is_equal_approx(host.to_global(Vector3.ZERO)), "Reverse route ends at original start")
	check(route.assign([first], true) and route.sample_ahead(45).is_equal_approx(host.to_global(Vector3.ZERO)), "First road can be explicitly reversed")
	second.position.x = 5.0
	var previous: Curve3D = route.curve
	check(not route.assign([first, second]) and route.curve == previous, "Disconnected assignment is rejected atomically")
	host.free()
	check(not route.is_valid(), "Removed infrastructure invalidates the route")
	return true

## Run the same physical scenario in small phases, counting an aborted phase as
## a failure while still restoring fixture nodes and session globals afterward.
func test_driving() -> bool:
	var fixture: DrivingFixture = _create_driving_fixture()
	for frame: int in range(4):
		await tree.process_frame
	fixture.body = fixture.manager.spawn_road_vehicle("trabant_601_green", [9101])
	check(fixture.body != null, "Production service spawns a road vehicle with its route")
	if fixture.body == null:
		_free_driving_fixture(fixture)
		return false
	var phases: Array[StringName] = [
		&"_test_automatic_acceleration", &"_test_takeover", &"_test_route_resumption",
		&"_test_free_steering_and_exit", &"_test_offroad_deletion", &"_test_terminal_stop"
	]
	for phase: StringName in phases:
		if await call(phase, fixture) != true:
			check(false, "%s aborted" % phase)
			break
	_free_driving_fixture(fixture)
	return true

func _create_driving_fixture() -> DrivingFixture:
	var fixture := DrivingFixture.new()
	fixture.previous_roads = Managers.roads
	fixture.previous_vehicles = Managers.vehicles
	fixture.previous_player = GlobalState.player
	fixture.previous_camera = GlobalState.active_cam
	fixture.roads = RoadsLoader.new()
	fixture.manager = VehiclePlacer.new()
	tree.root.add_child(fixture.roads)
	tree.root.add_child(fixture.manager)
	Managers.roads = fixture.roads
	Managers.vehicles = fixture.manager
	_add_fixture_road(fixture.roads)
	return fixture

## A straight approach followed by a bend tests both acceleration and steering.
func _add_fixture_road(roads: RoadsLoader) -> void:
	var road: RoadWay3D = load(RoadData.RURAL_ROAD_SCENE_PATH).instantiate()
	var data := RoadData.of(9101, "rural_road")
	data.curve = Curve3D.new()
	data.curve.add_point(Vector3.ZERO)
	data.curve.add_point(Vector3(0, 0, -70), Vector3(0, 0, 15), Vector3(0, 0, -15))
	data.curve.add_point(Vector3(15, 0, -100), Vector3(-15, 0, 0), Vector3(15, 0, 0))
	data.curve.add_point(Vector3(45, 0, -100))
	road.road = data
	roads.add_child(road)
	roads.storage.add_container(road)

func _test_automatic_acceleration(fixture: DrivingFixture) -> bool:
	var body: RoadVehicle3D = fixture.body
	await frames(60)
	var contacts: int = 0
	for child: Node in body.get_children():
		if child is VehicleWheel3D and child.is_in_contact():
			contacts += 1
	check(contacts >= 3, "Road geometry supports vehicle wheel contacts without terrain")
	var start: Vector3 = body.global_position
	await frames(180)
	check(body.global_position.distance_to(start) > 5.0, "Automatic driver physically accelerates along its route")
	check(body.global_position.y > 0.0 and body.global_position.y < 1.5, "Vehicle stays supported on the road")
	return true

## Capture walking settings before the service suspends the actual player scene.
func _add_fixture_player(fixture: DrivingFixture) -> void:
	fixture.outer_player = load("res://scenes/subscenes/player.tscn").instantiate()
	tree.root.add_child(fixture.outer_player)
	fixture.player = fixture.outer_player.get_node("Player")
	fixture.walking_process_mode = fixture.player.process_mode
	fixture.walking_mask = fixture.player.collision_mask
	fixture.walking_layer = fixture.player.collision_layer

func _test_takeover(fixture: DrivingFixture) -> bool:
	_add_fixture_player(fixture)
	var body: RoadVehicle3D = fixture.body
	var position_before: Vector3 = body.global_position
	var velocity_before: Vector3 = body.linear_velocity
	fixture.manager.enter_vehicle(body)
	check(fixture.manager.player_road_vehicle == body and body.player_driving, "Entering switches the input source")
	check(body.global_position == position_before and body.linear_velocity == velocity_before, "Takeover preserves position and momentum")
	check(fixture.player.process_mode == Node.PROCESS_MODE_DISABLED and fixture.player.collision_layer == 0, "Walking player cannot move or collide while driving")
	check(GlobalState.player.in_road_vehicle == body and GlobalState.active_cam == body.camera, "Player state and camera follow the road vehicle")
	body.apply_driver_input(0.0, -1.0, 0.0, 1.0 / 60.0)
	check(body.brake > 0.0 and is_zero_approx(body.engine_force), "Opposite pedal brakes before reverse")
	Input.action_press("move_right")
	body._physics_process(0.5)
	Input.action_release("move_right")
	check(body.steering < 0.0, "Right input steers right from the forward-facing chase camera")
	return true

func _test_route_resumption(fixture: DrivingFixture) -> bool:
	fixture.manager.exit_road_vehicle()
	var progress_before: float = fixture.body.route.progress
	await frames(60)
	check(fixture.body.route.progress > progress_before + 1.0, "Automatic route following resumes after releasing control on the road")
	fixture.manager.enter_vehicle(fixture.body)
	return true

## Hold real wheel steering over physics frames; movement must leave the centreline.
func _test_free_steering_and_exit(fixture: DrivingFixture) -> bool:
	var body: RoadVehicle3D = fixture.body
	body.set_physics_process(false)
	for frame: int in range(80):
		body.apply_driver_input(-1.0, 0.5, 0.0, 1.0 / 60.0)
		await tree.physics_frame
	check(absf(body.global_position.x) > 0.5, "Player steering moves the car away from the route centreline")
	var position_before: Vector3 = body.global_position
	var velocity_before: Vector3 = body.linear_velocity
	fixture.manager.exit_road_vehicle()
	check(not body.player_driving and fixture.manager.player_road_vehicle == null, "Leaving restores automatic route control")
	check(body.global_position == position_before and body.linear_velocity == velocity_before, "Release preserves position and momentum")
	check(fixture.player.process_mode == fixture.walking_process_mode and fixture.player.collision_layer == fixture.walking_layer and fixture.player.collision_mask == fixture.walking_mask, "Leaving restores original player collision and processing")
	check(GlobalState.active_cam == GlobalState.player.cam and GlobalState.player.in_road_vehicle == null, "Leaving restores walking camera and state")
	return true

func _test_offroad_deletion(fixture: DrivingFixture) -> bool:
	var body: RoadVehicle3D = fixture.body
	body.freeze = true
	body.global_position += Vector3(40, 0, 0)
	body._physics_process(1.0 / 60.0)
	check(body.brake > 0 and is_zero_approx(body.engine_force), "Off-route recovery holds the brakes without teleporting")
	fixture.manager.enter_vehicle(body)
	body.queue_free()
	await tree.process_frame
	check(fixture.manager.player_road_vehicle == null and fixture.player.collision_mask == fixture.walking_mask, "Deleting an occupied vehicle restores the player")
	return true

## A fresh, uninterrupted run reaches the bend and terminal stop.
func _test_terminal_stop(fixture: DrivingFixture) -> bool:
	fixture.body = fixture.manager.spawn_road_vehicle("trabant_601_green", [9101])
	var completions: Array[int] = [0]
	fixture.body.route_finished.connect(func(): completions[0] += 1)
	await frames(1800)
	check(fixture.body.global_position.y > 0.0 and fixture.body.global_position.y < 1.5, "Automatic driver stays on the road through its bend")
	check(completions[0] == 1 and absf(fixture.body.signed_speed_mps()) < 0.3, "Automatic driver stops at route end and signals once")
	return true

func _free_driving_fixture(fixture: DrivingFixture) -> void:
	if is_instance_valid(fixture.outer_player):
		fixture.outer_player.free()
	fixture.manager.free()
	fixture.roads.free()
	Managers.roads = fixture.previous_roads
	Managers.vehicles = fixture.previous_vehicles
	GlobalState.player = fixture.previous_player
	GlobalState.active_cam = fixture.previous_camera

## Both endpoint directions use world metres even under a transformed road parent.
func test_depot_spawning() -> bool:
	# Arrange a scaled, rotated road to distinguish local offsets from world metres.
	var fixture: DrivingFixture = _create_driving_fixture()
	var road: RoadWay3D = fixture.roads.storage.get_container_by_num(9101)
	road.transform = Transform3D(Basis(Vector3.UP, 0.45).scaled(Vector3.ONE * 1.5), Vector3(30, 8, 20))
	var path: Path3D = road.get_path_3d()
	var depot := RoadDepotData.new()
	depot.road_num = 9101

	# Exercise both endpoint directions through the public depot-spawning API.
	for endpoint: String in ["START", "END"]:
		depot.road_pos = endpoint
		var body: RoadVehicle3D = fixture.manager.spawn_road_vehicle_at_depot("daimler_1911_bus", depot)
		check(body != null, "Daimler bus spawns from a %s depot" % endpoint)
		if body == null:
			continue

		# Check arc distance and heading independently of the spawn implementation.
		var offset: float = 10.0 / 1.5
		if endpoint == "END":
			offset = path.curve.get_baked_length() - offset
		var expected: Vector3 = path.to_global(path.curve.sample_baked(offset))
		check((body.global_position - Vector3.UP * 0.8).distance_to(expected) < 0.05, "Spawn is 10 world metres along the road from %s" % endpoint)
		var tangent: Vector3 = path.to_global(path.curve.sample_baked(offset + 0.1)) - path.to_global(path.curve.sample_baked(offset - 0.1))
		if endpoint == "END":
			tangent = -tangent
		check(body.global_basis.z.dot(tangent.normalized()) > 0.999, "Vehicle faces away from the %s depot" % endpoint)
		# The imported bus nose points along the mesh scene's local +X axis.
		var mesh: Node3D = body.get_node_or_null("StaticDaimler1911Bus/MeshDaimler1911Bus")
		check(mesh != null and mesh.global_basis.x.normalized().dot(tangent.normalized()) > 0.999,
			"Daimler bus nose faces away from the %s depot" % endpoint)
		check(not body.route.is_valid() and body.brake > 0, "Depot bus is parked without an automatic route")

		# A rejected duplicate must not leave a registered car behind.
		check(fixture.manager.spawn_road_vehicle_at_depot("trabant_601_green", depot) == null, "An occupied depot spawn point rejects another car")
		check(fixture.manager.road_vehicles.size() == 1, "Rejected spawn leaves no extra vehicle registered")
		body.free()

	# Reject roads too short for the requested distance instead of clamping it.
	path.curve = Curve3D.new()
	path.curve.add_point(Vector3.ZERO)
	path.curve.add_point(Vector3(0, 0, -5))
	check(fixture.manager.spawn_road_vehicle_at_depot("trabant_601_green", depot) == null, "Road shorter than 10 world metres rejects spawning")

	# Restore session globals so subsequent tests remain independent.
	_free_driving_fixture(fixture)
	return true

## The click request opens a road-only selector and its actual button spawns a car.
func test_spawn_dialog() -> bool:
	# Arrange an actual SpawnAction subscriber and remember the surrounding UI state.
	var fixture: DrivingFixture = _create_driving_fixture()
	_add_fixture_player(fixture)
	var previous_dialog: GameDialog = UiState.current_diag
	var previous_mouse: Input.MouseMode = Input.mouse_mode
	var previous_blocked: bool = UiState.movement_blocked
	var depot := RoadDepotData.new()
	depot.depot_name = "Test road depot"
	depot.road_num = 9101
	depot.road_pos = "START"
	var action: Node = load("res://game/gamescripts/actions/spawn_action.gd").new()
	tree.root.add_child(action)

	# Open through the same signal used by a road-depot click.
	SignalBus.request_road_vehicle_spawn.emit(depot)
	var dialog: GameDialog = UiState.current_diag
	check(dialog != null and dialog.dialog_key == "SpawnRoadVehicleDialog", "Road request opens the car spawning dialog")
	if dialog == null:
		action.free()
		_free_driving_fixture(fixture)
		return false
	check(dialog.get("_list").item_count == 5, "Selector lists the five road vehicles without trains")
	check(UiState.movement_blocked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Dialog blocks world controls and exposes the mouse")
	check(fixture.player.process_mode == Node.PROCESS_MODE_DISABLED, "Dialog suspends the actual walking player")

	# Activate the real button, then let queued dialog cleanup finish.
	(dialog.get_node("%OkButton") as Button).pressed.emit()
	check(fixture.manager.road_vehicles.size() == 1, "Spawn button creates the selected car")
	await tree.process_frame
	check(UiState.current_diag == null and UiState.movement_blocked == previous_blocked, "Successful spawning closes the dialog and restores controls")
	check(Input.mouse_mode == previous_mouse, "Dialog restores the previous mouse mode")
	check(fixture.player.process_mode == fixture.walking_process_mode, "Closing restores the original walking process mode")

	# A second attempt shows the occupancy error and can be cancelled safely.
	SignalBus.request_road_vehicle_spawn.emit(depot)
	dialog = UiState.current_diag
	(dialog.get_node("%OkButton") as Button).pressed.emit()
	check(not dialog.is_queued_for_deletion() and dialog.get("_error").visible, "Occupied spawn reports an error and keeps the dialog open")
	dialog.close_all()
	await tree.process_frame
	check(UiState.current_diag == null and fixture.manager.road_vehicles.size() == 1, "Cancel closes without spawning another car")

	# Release the signal subscriber and restore the previous session.
	action.free()
	UiState.current_diag = previous_dialog
	_free_driving_fixture(fixture)
	return true
