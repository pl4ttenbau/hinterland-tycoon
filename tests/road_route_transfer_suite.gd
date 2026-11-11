extends RefCounted

var tree: SceneTree
var host: Node3D
var stops: Dictionary = {}
var road: RoadData
var passed: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	GameTypes.ensure_initialized()
	var old_stops: RoadStopsLoader = Managers.road_stops
	var old_roads: RoadsLoader = Managers.roads
	var old_vehicles: VehiclePlacer = Managers.vehicles
	var old_catalog: InterchangesLoader = Managers.interchanges
	_setup()
	for test: StringName in test_names():
		if await call(test) != true:
			check(false, "%s aborted" % test)
	host.free()
	for stop: AbstractStation in stops.values():
		stop.connections.parent = null
	for node: RoadNode in road.nodes:
		node.parent_track = null
	Managers.road_stops = old_stops
	Managers.roads = old_roads
	Managers.vehicles = old_vehicles
	Managers.interchanges = old_catalog
	print("%s: %d passed, %d failures" % [suite_name(), passed, failures])
	return 0 if failures == 0 else 1

func test_names() -> Array[StringName]:
	return [&"test_cargo", &"test_passengers", &"test_invalid_actions", &"test_ordered_execution", &"test_physical_passenger_route"]

func suite_name() -> String:
	return "Road route transfer tests"

func _setup() -> void:
	host = Node3D.new()
	tree.root.add_child(host)
	Managers.road_stops = RoadStopsLoader.new()
	Managers.roads = RoadsLoader.new()
	Managers.vehicles = VehiclePlacer.new()
	Managers.interchanges = InterchangesLoader.new()
	for service: Node in [Managers.road_stops, Managers.roads, Managers.vehicles, Managers.interchanges]:
		host.add_child(service)
	road = RoadMapper.road_from_data_json({"num": 100, "type": "rural_road", "autosmooth": false, "points": [
		{"pos": [0, 0, 0]}, {"pos": [0, 0, -30]}, {"pos": [0, 0, -60]}, {"pos": [0, 0, -100]}]})
	road.build_curve()
	Managers.roads.storage._list.append(road)
	Managers.roads.storage._by_id[100] = road
	var view: RoadWay3D = road.spawn()
	Managers.roads.add_child(view)
	Managers.roads.storage.add_container(view)

func _stop(id: int, index: int = 0, interchange_id: int = -1) -> RoadStationData:
	var data := RoadStationData.new(id, "Stop %d" % id)
	if interchange_id >= 0:
		var catalog: InterchangesLoader = Managers.interchanges
		var interchange: InterchangeData = catalog.by_num.get(interchange_id)
		if interchange == null:
			interchange = InterchangeData.new()
			interchange.num = interchange_id
			interchange.interchange_name = "Station %d" % interchange_id
			catalog.by_num[interchange_id] = interchange
			catalog.interchanges.append(interchange)
		data.interchange = interchange
		interchange.stops.append(data)
	data.road_num = road.num
	data.node_index = index
	data.position = road.nodes[index].position + Vector3(4, 0, 0)
	data.hide_building = true
	var view: BusStop3D = load("res://scenes/subscenes/infr/station/bus_stop_3d.tscn").instantiate()
	view.station = data
	Managers.road_stops.add_child(view)
	Managers.road_stops.containers_by_num[id] = view
	Managers.interchanges.stops_by_num[id] = data
	stops[id] = data
	return data

func _vehicle(key: String = "gaz_aa_truck") -> RoadVehicle3D:
	var body := RoadVehicle3D.of(key)
	body.freeze = true
	body.set_physics_process(false)
	host.add_child(body)
	return body

func _point(id: int, actions: Array[RoadRouteAction] = []) -> RoadRoutePoint:
	var point := RoadRoutePoint.new()
	point.kind = RoadRoutePoint.Kind.STOP
	point.target_num = id
	point.actions = actions
	return point

func _action(kind: RoadRouteAction.Kind, goods: Array[StringName], goals: Array[int] = []) -> RoadRouteAction:
	var action := RoadRouteAction.new()
	action.kind = kind
	action.goods = goods
	action.passenger_interchange_targets = goals
	return action

func _execute(body: RoadVehicle3D, stop: AbstractStation, action: RoadRouteAction) -> RoadRouteTransferResult:
	return RoadRouteTransferService.execute(body, _point(stop.num), action, stops)

# Ordered, stable cargo rows share the truck's capacity and conserve each resource.
func test_cargo() -> bool:
	var stop: RoadStationData = _stop(0)
	var body: RoadVehicle3D = _vehicle()
	var stock: GoodsInventory = stop.get_inventory_view().get_inventory()
	stock.change_stack(&"lumber", -1, 5)
	stock.change_stack(&"tools", -1, 3)
	var load := _action(RoadRouteAction.Kind.LOAD, [&"lumber", &"tools"])
	var result: RoadRouteTransferResult = _execute(body, stop, load)
	check(result.error.is_empty() and result.moved == 4, "Load moves up to the GAZ's shared capacity")
	check(body.get_inventory().get_amount("lumber") == 4 and stock.get_amount("lumber") == 1, "Cargo load conserves lumber")
	check(stock.get_amount("tools") == 3, "Later selected resources cannot overfill the vehicle")
	result = _execute(body, stop, load)
	check(result.error.is_empty() and result.moved == 0, "Loading a full vehicle is a successful no-op")

	var component: InventoryContainer = InventoryContainer.find_on(stop.get_inventory_view())
	component.capacity_override = 6
	var unload := _action(RoadRouteAction.Kind.UNLOAD, [&"lumber"])
	result = _execute(body, stop, unload)
	check(result.error.is_empty() and result.moved == 2, "Unloading respects remaining stop capacity")
	check(body.get_inventory().get_amount("lumber") == 2 and stock.get_amount("lumber") == 3, "Partial unload leaves excess aboard")
	result = _execute(body, stop, unload)
	check(result.error.is_empty() and result.moved == 0, "Unloading at a full stop does not wait indefinitely")
	body.free()
	return true

# Passenger selection stays goal-specific. At their goal they leave the simulation,
# even if its waiting inventory is full; other batches remain aboard or waiting.
func test_passengers() -> bool:
	var origin: RoadStationData = _stop(10)
	# Both stops serve interchange 11. Unload at the second physical stop.
	_stop(11, 0, 11)
	var destination: RoadStationData = _stop(111, 0, 11)
	_stop(12, 0, 12)
	var body: RoadVehicle3D = _vehicle("trabant_601_green")
	var stock: GoodsInventory = origin.get_inventory_view().get_inventory()
	stock.change_stack(&"passenger", 11, 3)
	stock.change_stack(&"passenger", 12, 2)
	stock.change_stack(&"passenger", -1, 1)
	var result: RoadRouteTransferResult = _execute(body, origin, _action(RoadRouteAction.Kind.LOAD, [&"passenger"], [11]))
	check(result.error.is_empty() and result.moved == 3, "Load selects only the requested interchange")
	check(stock.stack_amount(&"passenger", 12) == 2 and stock.stack_amount(&"passenger") == 1, "Other and unassigned passenger batches are untouched")
	result = _execute(body, origin, _action(RoadRouteAction.Kind.LOAD, [&"passenger"], [12]))
	check(result.error.is_empty() and result.moved == 1, "Passenger loading respects whole-person capacity")

	var target_stock: GoodsInventory = destination.interchange.inventory
	target_stock.amount_max = 0
	var unload := _action(RoadRouteAction.Kind.UNLOAD, [&"passenger"], [11])
	result = _execute(body, destination, unload)
	check(result.error.is_empty() and result.completed_passengers == 3, "Arriving passengers complete their trips despite a full waiting room")
	check(body.get_inventory().storage.total_passengers == 1 and target_stock.storage.total_passengers == 0, "Finished passengers are removed rather than added to waiting stock")
	result = _execute(body, destination, unload)
	check(result.error.is_empty() and result.moved == 0, "Repeated arrival cannot remove a different destination batch")

	var stop_end: InventoryEndpoint = InventoryEndpoint.from_node(destination.get_inventory_view())
	var wrong_goal := InventoryStack.new(&"passenger", 1, 12)
	check(not InventoryTransferService.completes_passenger_trip(stop_end, wrong_goal), "The wrong interchange cannot complete the trip")
	target_stock.amount_max = 10
	result = _execute(body, destination, _action(RoadRouteAction.Kind.UNLOAD, [&"passenger"], [12]))
	check(result.error.is_empty() and result.completed_passengers == 0 and result.moved == 1, "Explicit intermediate unload preserves a waiting passenger's onward goal")
	check(target_stock.stack_amount(&"passenger", 12) == 1, "Intermediate passengers retain the original destination ID")
	body.free()
	return true

# Runtime validation covers changed access and action data before changing stock.
func test_invalid_actions() -> bool:
	var stop: RoadStationData = _stop(15)
	var body: RoadVehicle3D = _vehicle()
	var stock: GoodsInventory = stop.get_inventory_view().get_inventory()
	stock.change_stack(&"lumber", -1, 4)
	var load := _action(RoadRouteAction.Kind.LOAD, [&"lumber"])
	body.player_driving = true
	check(not _execute(body, stop, load).error.is_empty(), "Manual control prevents automatic transfers")
	body.player_driving = false
	body.linear_velocity = Vector3(0, 0, 2)
	check(not _execute(body, stop, load).error.is_empty(), "A moving vehicle cannot transfer")
	body.linear_velocity = Vector3.ZERO
	body.position.x = 30
	check(not _execute(body, stop, load).error.is_empty(), "A distant stop cannot transfer")
	body.position = Vector3.ZERO
	check(not _execute(body, stop, _action(RoadRouteAction.Kind.LOAD, [&"passenger"], [11])).error.is_empty(), "Vehicle cargo category is validated")
	check(not _execute(body, stop, _action(RoadRouteAction.Kind.LOAD, [&"missing"])).error.is_empty(), "Unknown goods are rejected")
	check(not RoadRouteTransferService.execute(body, _point(999), load, stops).error.is_empty(), "Deleted stops are rejected")
	check(stock.get_amount("lumber") == 4 and body.get_inventory().amount_used == 0, "Rejected actions leave both inventories unchanged")
	body.free()
	return true

# Starting beside a stop while driving must not mutate stock. Then verify unload
# before load, next-point advancement, and no repeat once the visit is complete.
func test_ordered_execution() -> bool:
	var first: RoadStationData = _stop(20)
	var last: RoadStationData = _stop(21, 3)
	var body: RoadVehicle3D = _vehicle()
	body.position.y = 0.8
	# This fixture tests actions only; face the next stop to avoid a U-turn phase.
	body.rotation.y = PI
	body.get_inventory().change_stack(&"lumber", -1, 4)
	var stock: GoodsInventory = first.get_inventory_view().get_inventory()
	stock.change_stack(&"tools", -1, 4)
	var unload := _action(RoadRouteAction.Kind.UNLOAD, [&"lumber"])
	var load := _action(RoadRouteAction.Kind.LOAD, [&"tools"])
	body.route_plan.points = [_point(20, [unload, load]), _point(21, [load])]
	body.player_driving = true
	check(body.plan_execution.start(body), "Plan starts beside the first stop under manual control")
	body.plan_execution.tick(body)
	check(body.get_inventory().get_amount("lumber") == 4 and stock.get_amount("tools") == 4, "Start and manual tick do not execute stop actions")
	body.player_driving = false
	body.linear_velocity = Vector3(0, 0, 2)
	body.plan_execution.tick(body)
	check(body.get_inventory().get_amount("tools") == 0, "Servicing waits until the vehicle is stationary")
	body.linear_velocity = Vector3.ZERO
	body.plan_execution.tick(body)
	check(body.get_inventory().get_amount("lumber") == 0 and body.get_inventory().get_amount("tools") == 4, "Ordered unload frees capacity for the following load")
	check(body.plan_execution.running and body.plan_execution.current_point == 1, "Successful actions advance to the next visit")

	body.global_position = road.nodes[3].position + Vector3.UP * 0.8
	body._arrived = true
	body.plan_execution.tick(body)
	body.plan_execution.tick(body)
	check(body.plan_execution.status == "Plan complete", "No stock at the final load action still completes the plan")
	var amount: float = body.get_inventory().amount_used
	body.plan_execution.tick(body)
	check(body.get_inventory().amount_used == amount, "Completed plans do not repeat their actions")
	body.free()
	return true

# Real physics picks up passengers at one roadside stop and finishes their trips
# at another, using the same controller and arrival path as the game.
func test_physical_passenger_route() -> bool:
	var origin: RoadStationData = _stop(30, 1)
	var destination: RoadStationData = _stop(31, 3, 31)
	var stock: GoodsInventory = origin.get_inventory_view().get_inventory()
	stock.change_stack(&"passenger", 31, 4)
	var depot := RoadDepotData.new()
	depot.road_num = road.num
	depot.road_pos = "START"
	var body: RoadVehicle3D = Managers.vehicles.spawn_road_vehicle_at_depot("trabant_601_green", depot)
	check(body != null, "Passenger car spawns for physical integration")
	if body == null:
		return false
	var load := _action(RoadRouteAction.Kind.LOAD, [&"passenger"], [31])
	var unload := _action(RoadRouteAction.Kind.UNLOAD, [&"passenger"], [31])
	body.route_plan.points = [_point(30, [load]), _point(31, [unload])]
	var changes: Array[int] = [0]
	body.get_inventory().goods_change.connect(func(): changes[0] += 1)
	check(body.plan_execution.start(body), "Physical passenger route starts")
	for frame: int in range(2700):
		await tree.physics_frame
	check(body.plan_execution.status == "Plan complete", "Vehicle reaches both physical stops and completes both actions")
	check(changes[0] == 2 and body.get_inventory().storage.total_passengers == 0, "Exactly one pickup and one completed-trip mutation occur")
	check(stock.storage.total_passengers == 0 and destination.get_inventory_view().get_inventory().storage.total_passengers == 0, "Finished trips leave no passengers waiting at either stop")
	check(body.global_position.z < -95, "Transfers finish at the actual destination rather than before arrival")
	body.free()
	return true
