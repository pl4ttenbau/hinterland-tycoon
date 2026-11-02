extends RefCounted

var tree: SceneTree
var host: Node3D
var passed: int = 0
var failures: int = 0
var stops: Array[AbstractStation] = []
var interchange: InterchangeData

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	GameTypes.ensure_initialized()
	var old_road_stops: RoadStopsLoader = Managers.road_stops
	var old_stations: StationsHolder = Managers.stations
	var old_map: MapData = GlobalState.loaded_map
	var old_houses: Array[Residence3D] = GlobalState.res_bld_containers.duplicate()
	var old_data: Array[ResidenceBuildingData] = GlobalState.res_blds.duplicate()
	var old_number: int = Residence3D.last_bld_num
	_setup()

	# An aborted test counts as a failure, while cleanup still restores all globals.
	for test: StringName in [&"test_weighted_choice", &"test_trip_planning", &"test_direct_spawning"]:
		if call(test) != true:
			check(false, "%s aborted" % test)
	host.free()
	for stop: AbstractStation in stops:
		stop.connections.parent = null
		stop.interchange = null
	interchange.stops.clear()
	interchange.connections.parent = null
	Managers.road_stops = old_road_stops
	Managers.stations = old_stations
	GlobalState.loaded_map = old_map
	GlobalState.res_bld_containers = old_houses
	GlobalState.res_blds = old_data
	Residence3D.last_bld_num = old_number
	print("Passenger spawning tests: %d passed, %d failures" % [passed, failures])
	return 0 if failures == 0 else 1

# Use actual bus/rail inventory views, including valid physical stop ID zero.
func _setup() -> void:
	host = Node3D.new()
	tree.root.add_child(host)
	Managers.road_stops = RoadStopsLoader.new()
	Managers.stations = StationsHolder.new()
	host.add_child(Managers.road_stops)
	host.add_child(Managers.stations)
	interchange = InterchangeData.new()
	interchange.num = 999
	interchange.interchange_name = "Shared station"
	var road := RoadStationData.new(0, "Road stop")
	road.hide_building = true
	var road_view: BusStop3D = load("res://scenes/subscenes/infr/station/bus_stop_3d.tscn").instantiate()
	road_view.station = road
	Managers.road_stops.add_child(road_view)
	Managers.road_stops.containers_by_num[0] = road_view
	var rail := RailStationData.new(17, "Rail stop")
	var rail_view: RailStation3D = load(StationsHolder.STATION_3D_SCENE_PATH).instantiate()
	rail_view.station = rail
	Managers.stations.add_child(rail_view)
	stops = [road, rail]
	for stop: AbstractStation in stops:
		stop.interchange = interchange
		interchange.stops.append(stop)

func _house(first: int, second: int, stop: AbstractStation = null) -> Residence3D:
	var type := ResBldType.new("test_house", "Test house", 0)
	type.pops = [first, second]
	var view := Residence3D.new()
	view.res_bld_obj = ResidenceBuildingData.new(1, type)
	if stop != null:
		view.res_bld_obj.connected_interchange = interchange
		view.res_bld_obj.reachable_stops = [stop]
	host.add_child(view)
	return view

# Match exact seeded ticket draws, avoiding a probabilistic/flaky frequency test.
func test_weighted_choice() -> bool:
	var small: Residence3D = _house(1, 2)
	var large: Residence3D = _house(4, 5)
	var empty: Residence3D = _house(0, 0)
	var planner := PassengerTripPlanner.new()
	planner.refresh([small, large, empty])
	planner.random.seed = 12345
	var expected := RandomNumberGenerator.new()
	expected.seed = 12345
	for draw: int in range(16):
		var house: ResidenceBuildingData = small.res_bld_obj if expected.randi_range(0, 11) < 3 else large.res_bld_obj
		check(planner.choose_residence() == house, "Draw uses the sum of both population groups as its exact weight")
	check(planner.choose_residence(small.res_bld_obj) == large.res_bld_obj, "Origin exclusion retains other residence weights")
	check(planner._choices.size() == 2, "Disconnected houses remain in the draw; empty houses do not")
	planner.refresh([empty])
	check(planner.choose_residence() == null and planner.plan() == null, "Zero total population safely discards the attempt")
	var before_removal: Array[Residence3D] = [small, large]
	large.free()
	planner.refresh(before_removal)
	check(planner.choose_residence() == small.res_bld_obj, "Removed residence views are ignored on refresh")
	return true

# Pick a reproducible origin for connection-rejection tests, then reset the RNG.
func _choose_origin(planner: PassengerTripPlanner, wanted: ResidenceBuildingData) -> void:
	for seed_value: int in range(64):
		planner.random.seed = seed_value
		if planner.choose_residence() == wanted:
			planner.random.seed = seed_value
			return
	check(false, "Fixture could not select its requested origin")

# Every plan has two concrete physical stops; failed destinations are never rerolled.
func test_trip_planning() -> bool:
	var origin: Residence3D = _house(2, 1, stops[0])
	var destination: Residence3D = _house(5, 2, stops[1])
	var planner := PassengerTripPlanner.new()
	planner.refresh([origin, destination])
	_choose_origin(planner, origin.res_bld_obj)
	var request: PassengerSpawnRequest = planner.plan()
	check(request != null and request.origin_stop == stops[0] and request.destination_stop == stops[1], "Trip can link road and rail stops in the same interchange")
	check(request.origin_residence_num == origin.num and request.destination_residence_num == destination.num, "Trip DTO keeps its distinct origin and target residence IDs")
	check(request.destination_stop.num == 17 and request.destination_stop.num != interchange.num, "Target identity is the physical stop, not the interchange")

	destination.res_bld_obj.reachable_stops.clear()
	_choose_origin(planner, origin.res_bld_obj)
	var expected := RandomNumberGenerator.new()
	expected.state = planner.random.state
	expected.randi_range(0, 9)
	expected.randi_range(0, 6)
	check(planner.plan() == null, "Unconnected target residence discards the passenger")
	check(planner.random.state == expected.state, "Rejected target consumes exactly one destination draw without retrying")
	_choose_origin(planner, destination.res_bld_obj)
	check(planner.plan() == null, "Unconnected origin also discards the attempt")

	destination.res_bld_obj.reachable_stops = [stops[0]]
	check(planner.plan() == null, "Trips already at their destination stop are skipped")
	planner.refresh([origin])
	check(planner.plan() == null, "A lone residence cannot create a trip to itself")
	return true

# Exercise the actual timer callback and verify direct destination-aware stock.
func test_direct_spawning() -> bool:
	var a: Residence3D = _house(2, 1, stops[0])
	var b: Residence3D = _house(4, 2, stops[1])
	GlobalState.res_bld_containers = [a, b]
	GlobalState.loaded_map = MapData.new()
	var spawner := StationGoodsSpawner.new()
	var timer := Timer.new()
	timer.name = "SpawnPassengersTimer"
	spawner.add_child(timer)
	host.add_child(spawner)
	check(not spawner.spawn_rnd_passenger(), "Spawning waits for map selection")
	spawner._on_map_selected(GlobalState.loaded_map)
	check(spawner.spawn_rnd_passenger(), "Connected trip spawns successfully")
	timer.timeout.emit()
	var first: GoodsInventory = stops[0].get_inventory_view().get_inventory()
	var second: GoodsInventory = stops[1].get_inventory_view().get_inventory()
	check(first.storage.total_passengers + second.storage.total_passengers == 2, "Each attempt creates exactly one passenger in a stop inventory")
	check(first.stack_amount(&"passenger") == 0 and second.stack_amount(&"passenger") == 0, "New spawns never enter the unassigned group")
	check(first.stack_amount(&"passenger", 17) + second.stack_amount(&"passenger", 0) == 2, "Both origin directions preserve their physical target ID")

	# Check capacity at the origin only; a full target does not erase travel demand.
	var request := PassengerSpawnRequest.new(a.res_bld_obj, b.res_bld_obj, stops[0], stops[1])
	var origin_component: InventoryContainer = InventoryContainer.find_on(stops[0].get_inventory_view())
	var target_component: InventoryContainer = InventoryContainer.find_on(stops[1].get_inventory_view())
	target_component.capacity_override = 0
	check(spawner.spawn_passenger(request), "Full destination inventory does not block spawning at the origin")
	origin_component.capacity_override = 0
	var before: float = first.storage.total_passengers
	check(not spawner.spawn_passenger(request) and first.storage.total_passengers == before, "Full origin rejects a spawn without changing stock")
	origin_component.capacity_override = -1
	first.amount_max = 60
	origin_component.accepted_categories = [BaseGoodsType.ResourceCategory.FREIGHT]
	check(not spawner.spawn_passenger(request), "Origin category restrictions are respected")
	origin_component.accepted_categories.clear()
	check(not spawner.spawn_passenger(null), "Discarded plans have no fallback spawn")
	stops[1].get_inventory_view().free()
	check(not spawner.spawn_passenger(request), "A removed destination view cannot leave an orphan passenger")
	return true
