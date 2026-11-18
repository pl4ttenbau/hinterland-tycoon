extends RefCounted

var tree: SceneTree
var host: Node3D
var passed: int = 0
var failures: int = 0
var stops: Array[AbstractStation] = []
var interchange: InterchangeData
var destination_interchange: InterchangeData

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
	var old_catalog: InterchangesLoader = Managers.interchanges
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
	for station: InterchangeData in [interchange, destination_interchange]:
		station.stops.clear()
		station.connections.parent = null
	Managers.interchanges = old_catalog
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
	Managers.interchanges = InterchangesLoader.new()
	host.add_child(Managers.interchanges)
	interchange = InterchangeData.new()
	interchange.num = 999
	interchange.interchange_name = "Origin"
	destination_interchange = InterchangeData.new()
	destination_interchange.num = 1000
	destination_interchange.interchange_name = "Destination"
	Managers.interchanges.interchanges.assign([interchange, destination_interchange])
	var road := RoadStationData.new(0, "Road stop")
	road.interchange = interchange
	road.hide_building = true
	var road_view: BusStop3D = load("res://scenes/subscenes/infr/station/bus_stop_3d.tscn").instantiate()
	road_view.station = road
	Managers.road_stops.add_child(road_view)
	Managers.road_stops.containers_by_num[0] = road_view
	var rail := RailStationData.new(17, "Rail stop")
	rail.interchange = destination_interchange
	var rail_view: RailStation3D = load(StationsHolder.STATION_3D_SCENE_PATH).instantiate()
	rail_view.station = rail
	Managers.stations.add_child(rail_view)
	stops = [road, rail]
	interchange.stops.assign([road])
	destination_interchange.stops.assign([rail])

func _house(first: int, second: int, stop: AbstractStation = null) -> Residence3D:
	var type := ResBldType.new("test_house", "Test house", 0)
	type.pops = [first, second]
	var view := Residence3D.new()
	view.res_bld_obj = ResidenceBuildingData.new(1, type)
	if stop != null:
		view.res_bld_obj.connected_interchange = stop.interchange
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

# Every plan resolves live access points; failed destinations are never rerolled.
func test_trip_planning() -> bool:
	var origin: Residence3D = _house(2, 1, stops[0])
	var destination: Residence3D = _house(5, 2, stops[1])
	var planner := PassengerTripPlanner.new()
	planner.refresh([origin, destination])
	_choose_origin(planner, origin.res_bld_obj)
	var request: PassengerSpawnRequest = planner.plan()
	check(request != null and request.origin_stop == stops[0] and request.destination_interchange == destination_interchange, "A road origin can target an interchange served by rail")
	check(request.origin_residence_num == origin.num and request.destination_residence_num == destination.num, "Trip DTO keeps its distinct origin and target residence IDs")
	check(request.destination_interchange.num == 1000, "Target identity uses the interchange ID")

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

	# Even distinct physical stops must not create a trip within one interchange.
	destination.res_bld_obj.reachable_stops = [stops[1]]
	stops[1].interchange = interchange
	check(planner.plan() == null, "Trips between stops in the same interchange are skipped")
	stops[1].interchange = destination_interchange
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
	# Old stock may already be waiting at its own destination.
	var origin_stock: GoodsInventory = interchange.inventory
	var destination_stock: GoodsInventory = destination_interchange.inventory
	origin_stock.change_stack(&"passenger", interchange.num, 3)
	timer.timeout.emit()
	check(origin_stock.stack_amount(&"passenger", interchange.num) == 0, "The timer removes passengers already waiting at their destination")
	check(origin_stock.storage.total_passengers + destination_stock.storage.total_passengers == 2, "Two attempts create exactly two travellers")
	check(origin_stock.stack_amount(&"passenger") == 0 and destination_stock.stack_amount(&"passenger") == 0, "New travellers have assigned destinations")
	check(origin_stock.stack_amount(&"passenger", destination_interchange.num) + destination_stock.stack_amount(&"passenger", interchange.num) == 2, "Both directions store the destination interchange ID")

	var request := PassengerSpawnRequest.new(a.res_bld_obj, b.res_bld_obj, stops[0], destination_interchange)
	_check_spawn_capacity(spawner, request, origin_stock)
	check(not spawner.spawn_passenger(null), "Discarded plans have no fallback spawn")
	stops[1].get_inventory_view().free()
	check(not spawner.spawn_passenger(request), "A removed destination view cannot leave an orphan passenger")
	return true

func _check_spawn_capacity(spawner: StationGoodsSpawner, request: PassengerSpawnRequest, origin_stock: GoodsInventory) -> void:
	var target_stock: GoodsInventory = request.destination_interchange.inventory
	var destination_capacity: float = target_stock.amount_max
	target_stock.amount_max = 0.0
	check(spawner.spawn_passenger(request), "Full destination inventory does not block spawning at the origin")
	target_stock.amount_max = destination_capacity

	var before: float = origin_stock.storage.total_passengers
	var previous_capacity: float = origin_stock.amount_max
	origin_stock.amount_max = origin_stock.storage.current_storage
	check(not spawner.spawn_passenger(request) and origin_stock.storage.total_passengers == before, "Full origin rejects a spawn without changing stock")
	origin_stock.amount_max = previous_capacity

	var origin_component: InventoryContainer = InventoryContainer.find_on(stops[0].get_inventory_view())
	origin_component.accepted_categories = [BaseGoodsType.ResourceCategory.FREIGHT]
	check(not spawner.spawn_passenger(request), "Origin category restrictions are respected")
	origin_component.accepted_categories.clear()
