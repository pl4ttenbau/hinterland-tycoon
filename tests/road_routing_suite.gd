## Focused graph, route-data and dialog checks; no terrain or full map is required.
extends RefCounted

const MARKER_TOOL = preload("res://game/gamescripts/nodes/marker/road_marker_tool.gd")

var failed: int = 0
var passed: int = 0
var tree: SceneTree
var roads := RoadStore.new()
var network := RoadPathfinder.new()
var stops: Dictionary = {}
var depots: Array[RoadDepotData] = []

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error(message)

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	GameTypes.ensure_initialized()
	_setup_network()
	for test: StringName in [&"test_pathfinding", &"test_curved_cost", &"test_route_data", &"test_dialog", &"test_execution", &"test_markers"]:
		if await call(test) != true:
			check(false, "%s aborted" % test)
	_cleanup()
	print("Road routing tests: %d passed, %d failed" % [passed, failed])
	return 0 if failed == 0 else 1

## A shared intermediate junction joins two roads; a raised road remains separate.
func _setup_network() -> void:
	_add_road(10, [[0, 0, 0], [30, 0, 0], [60, 0, 0]])
	_add_road(20, [[30, 0, 0], [30, 0, -30], [30, 0, -60]])
	_add_road(30, [[30, 5, 0], [30, 5, -30]])
	RoadCross.of(roads._by_id[10].nodes[1], [20, 30])
	var stop := RoadStationData.new(201, "Destination")
	stop.road_num = 20
	stop.node_index = 2
	stops[201] = stop
	var depot := RoadDepotData.new()
	depot.num = 301
	depot.road_num = 10
	depot.road_pos = "END"
	depots.append(depot)
	network.build(roads.get_all())

func _add_road(id: int, positions: Array) -> void:
	var definition := {"num": id, "type": "rural_road", "autosmooth": false, "points": []}
	for position: Array in positions:
		definition.points.append({"pos": position})
	var road: RoadData = RoadMapper.road_from_data_json(definition)
	road.build_curve()
	# Keep this fixture local rather than registering its roads in GlobalState.
	roads._list.append(road)
	roads._by_id[id] = road

## Route from intermediate nodes, reverse along roads and cross only authored junctions.
func test_pathfinding() -> bool:
	var path: Array[RoadNode] = network.find_path(roads._by_id[10].nodes[2], roads._by_id[20].nodes[1])
	check(path.size() == 4, "Intermediate-node junction produces a connected four-node path")
	check(is_equal_approx(network.path_length(path), 60.0), "Graph measures road distance")
	check(network.find_path(roads._by_id[20].nodes[1], roads._by_id[10].nodes[2]).size() == 4, "Road travel supports both directions")
	check(network.find_path(roads._by_id[10].nodes[1], roads._by_id[30].nodes[0]).is_empty(), "Height-separated crossing cannot join despite its road reference")

	# Rebuilding must clear old topology rather than leaving stale paths.
	RoadCross.of(roads._by_id[10].nodes[1], [])
	network.build(roads.get_all())
	check(network.find_path(roads._by_id[10].nodes[0], roads._by_id[20].nodes[2]).is_empty(), "Missing authored connection is unreachable")
	RoadCross.of(roads._by_id[10].nodes[1], [20])
	network.build(roads.get_all())
	return true

func _node_point(road: int, index: int) -> RoadRoutePoint:
	var point := RoadRoutePoint.new()
	point.road_num = road
	point.node_index = index
	return point

## A direct-looking curved road must not beat a genuinely shorter connected route.
func test_curved_cost() -> bool:
	# Add a long bowed alternative between the same source/destination anchors.
	_add_road(40, [[0, 0, 0], [30, 0, -60]])
	var alternative: RoadData = roads._by_id[40]
	alternative.curve.set_point_out(0, Vector3(-200, 0, 0))
	alternative.curve.set_point_in(1, Vector3(200, 0, 0))
	RoadCross.of(roads._by_id[10].nodes[0], [40])
	RoadCross.of(alternative.nodes[1], [20])
	network.build(roads.get_all())

	# Compare physical travel distance, rather than endpoint chord distance.
	var path: Array[RoadNode] = network.find_path(roads._by_id[10].nodes[0], roads._by_id[20].nodes[2])
	check(is_equal_approx(network.path_length(path), 90.0), "Shortest path uses curve arc distances")
	return true

## Node/stop/depot references stay distinct; passenger selectors use physical stop IDs.
func test_route_data() -> bool:
	var plan := RoadRoutePlan.new()
	plan.points.append(_node_point(10, 0))
	var stop := RoadRoutePoint.new()
	stop.kind = RoadRoutePoint.Kind.STOP
	stop.target_num = 201
	plan.points.append(stop)
	var depot := RoadRoutePoint.new()
	depot.kind = RoadRoutePoint.Kind.DEPOT
	depot.target_num = 301
	plan.points.append(depot)
	check(depot.resolve(roads, stops, depots) == roads._by_id[10].nodes[2], "END depot resolves to its road endpoint")
	var action := RoadRouteAction.new()
	action.goods.append(&"passenger")
	stop.actions.append(action)
	check(not _validate(plan).is_empty(), "Passengers require an explicit physical destination")
	action.passenger_targets.append(201)
	check(_validate(plan).is_empty(), "Connected route with passenger destination validates")
	var good: BaseGoodsType = GameTypes.resource_types["passenger"]
	check(action.matches(good, 201) and not action.matches(good, 202), "Passenger destinations are selected independently")

	# Editing copies and resource round trips preserve action data without sharing it.
	var copy: RoadRoutePlan = plan.duplicate(true)
	copy.points[1].actions[0].passenger_targets.append(202)
	check(action.passenger_targets == [201], "Draft action edits do not mutate the saved plan")
	check(ResourceSaver.save(plan, "/tmp/road-routing-plan.tres") == OK, "Itinerary can be serialized")
	var loaded: RoadRoutePlan = ResourceLoader.load("/tmp/road-routing-plan.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.points[1].actions[0].passenger_targets == [201], "Round trip retains physical passenger targets")
	stop.target_num = 999
	check(not _validate(plan).is_empty(), "Deleted stop is rejected without retargeting")
	return true

func _validate(plan: RoadRoutePlan) -> String:
	return plan.validate(network, roads, stops, depots, GameTypes.resource_types, GameTypes.get_veh_type("oldtimer_car").capacity)

## Save/cancel exercise real controls and preserve the vehicle's driving state.
func test_dialog() -> bool:
	var previous_roads: RoadsLoader = Managers.roads
	var previous_interchanges: InterchangesLoader = Managers.interchanges
	var previous_depots: Array[RoadDepotData] = GlobalState.road_depots
	var loader := RoadsLoader.new()
	loader.storage = roads
	Managers.roads = loader
	var interchanges := InterchangesLoader.new()
	interchanges.stops_by_num = stops
	Managers.interchanges = interchanges
	GlobalState.road_depots = depots
	var vehicle := RoadVehicle3D.of("oldtimer_car")
	var script: GDScript = load("res://game/gamescripts/ui/dialogs/road_route/road_route_dialog.gd")
	var dialog: GameDialog = script.create(vehicle)
	tree.root.add_child(dialog)
	var draft: RoadRoutePlan = dialog.get("plan")
	draft.points.assign([_node_point(10, 0), _node_point(20, 2)])
	_check_action_editing(dialog)
	(dialog.get_node("%OkButton") as Button).pressed.emit()
	check(vehicle.route_plan.points.size() == 2, "Save assigns the connected draft to the vehicle")
	check(not vehicle.route.is_valid() and not vehicle.player_driving, "Saving does not start automatic driving")
	await tree.process_frame
	check(UiState.current_diag == null, "Route dialog releases modal state")

	# Cancelling an edited copy must retain the previously saved itinerary.
	dialog = script.create(vehicle)
	tree.root.add_child(dialog)
	(dialog.get("plan") as RoadRoutePlan).points.clear()
	dialog.close_all()
	await tree.process_frame
	check(vehicle.route_plan.points.size() == 2, "Cancel keeps the saved itinerary")
	vehicle.free()
	loader.free()
	interchanges.free()
	Managers.roads = previous_roads
	Managers.interchanges = previous_interchanges
	GlobalState.road_depots = previous_depots
	return true

## Exercise actual selector metadata, append order and action reordering in the draft.
func _check_action_editing(dialog: GameDialog) -> void:
	var draft: RoadRoutePlan = dialog.get("plan")
	var stop := RoadRoutePoint.new()
	stop.kind = RoadRoutePoint.Kind.STOP
	stop.target_num = 201
	draft.points[1] = stop
	dialog.call("_refresh_points", 1)
	var goods: ItemList = dialog.get("_goods")
	for index: int in range(goods.item_count):
		if goods.get_item_metadata(index) == &"passenger":
			goods.select(index)
	(dialog.get("_passenger_targets") as ItemList).select(0)
	dialog.call("_add_action")
	(dialog.get("_action_kind") as OptionButton).select(1)
	dialog.call("_add_action")
	check(stop.actions.size() == 2 and stop.actions[0].passenger_targets == [201], "Dialog adds load/unload actions with physical passenger targets")
	(dialog.get("_actions") as ItemList).select(1)
	dialog.call("_move_action", -1)
	check(stop.actions[0].kind == RoadRouteAction.Kind.UNLOAD, "Transfer actions can be reordered")

## Drive actual physics through multiple visits, then prove transfer instructions pause.
func test_execution() -> bool:
	# Arrange an isolated rendered road and real vehicle service.
	var old_roads: RoadsLoader = Managers.roads
	var old_vehicles: VehiclePlacer = Managers.vehicles
	var old_interchanges: InterchangesLoader = Managers.interchanges
	var loader := RoadsLoader.new()
	var manager := VehiclePlacer.new()
	var catalog := InterchangesLoader.new()
	Managers.roads = loader
	Managers.vehicles = manager
	Managers.interchanges = catalog
	tree.root.add_child(loader)
	tree.root.add_child(manager)
	var road: RoadData = RoadMapper.road_from_data_json({"num": 100, "type": "rural_road", "autosmooth": false, "points": [{"pos": [0,0,0]}, {"pos": [0,0,-30]}, {"pos": [0,0,-60]}, {"pos": [0,0,-100]}]})
	road.build_curve()
	loader.storage._list.append(road)
	loader.storage._by_id[100] = road
	var view: RoadWay3D = road.spawn()
	loader.add_child(view)
	loader.storage.add_container(view)
	for frame: int in range(4):
		await tree.process_frame
	var depot := RoadDepotData.new()
	depot.road_num = 100
	depot.road_pos = "START"
	var body: RoadVehicle3D = manager.spawn_road_vehicle_at_depot("trabant_601_green", depot)
	body.route_plan.points.assign([_node_point(100, 1), _node_point(100, 2), _node_point(100, 3)])
	check(body.plan_execution.start(body), "Plan starts from a current partial-road offset")

	await _check_manual_execution_and_completion(body)

	body.free()

	# A removed inventory must stop the car at its visit, never silently skip it.
	var stop := RoadStationData.new(401, "Transfer stop")
	stop.road_num = 100
	stop.node_index = 2
	catalog.stops_by_num[401] = stop
	body = manager.spawn_road_vehicle_at_depot("trabant_601_green", depot)
	var point := RoadRoutePoint.new()
	point.kind = RoadRoutePoint.Kind.STOP
	point.target_num = 401
	var action := RoadRouteAction.new()
	action.goods.append(&"passenger")
	action.passenger_targets.append(401)
	point.actions.append(action)
	body.route_plan.points.assign([_node_point(100, 1), point, _node_point(100, 3)])
	check(body.plan_execution.start(body), "Plan with a later transfer visit starts")
	await _check_transfer_pause_and_offroad_start(body)

	body.free()
	body = await _check_marker_execution(manager, loader, depot)

	# Restore globals and release data back-references.
	body.free()
	manager.free()
	loader.free()
	catalog.free()
	for node: RoadNode in road.nodes:
		node.parent_track = null
	stop.connections.parent = null
	Managers.roads = old_roads
	Managers.vehicles = old_vehicles
	Managers.interchanges = old_interchanges
	return true

## Manual takeover freezes visit advancement; release must reach the final physical stop.
func _check_manual_execution_and_completion(body: RoadVehicle3D) -> void:
	# Player takeover suspends plan advancement without losing its current visit.
	body.freeze = true
	body.set_player_driving(true)
	for frame: int in range(20):
		await tree.physics_frame
	check(body.plan_execution.current_point == 0, "Manual takeover preserves execution progress")
	body.set_player_driving(false)
	body.freeze = false
	for frame: int in range(2100):
		await tree.physics_frame
	check(body.plan_execution.status == "Plan complete", "Automatic physics visits all points and completes the plan")
	check(body.global_position.z < -95 and body.global_position.y > 0, "Vehicle reaches the final point on the physical road")

## Missing stop inventories and invalid starts hold the car instead of skipping visits.
func _check_transfer_pause_and_offroad_start(body: RoadVehicle3D) -> void:
	for frame: int in range(1500):
		await tree.physics_frame
	check(not body.plan_execution.running and "inventories" in body.plan_execution.status, "Execution reports a missing stop inventory and holds the visit")
	check(body.plan_execution.current_point == 1 and body.global_position.z > -65, "Transfer visit is not skipped")

	# An off-road start fails safely rather than teleporting onto the network.
	body.freeze = true
	body.global_position += Vector3(100, 0, 0)
	check(not body.plan_execution.start(body) and not body.plan_execution.running, "Starting far from a road rejects execution safely")



## Real physics follows named marker offsets without adding authored road nodes.
func _check_marker_execution(manager: VehiclePlacer, loader: RoadsLoader, depot: RoadDepotData) -> RoadVehicle3D:
	# Marker execution must stop at arbitrary offsets, not snap to authored road nodes.
	var body: RoadVehicle3D = manager.spawn_road_vehicle_at_depot("trabant_601_green", depot)
	var marker_points: Array[RoadRoutePoint] = []
	for offset: float in [37.0, 73.0]:
		var marker := RoadMarkerData.new()
		marker.num = loader.markers.next_num()
		marker.road_num = 100
		marker.offset = offset
		marker.side = Enums.RoadSide.RIGHT
		loader.markers.markers.append(marker)
		var target := RoadRoutePoint.new()
		target.kind = RoadRoutePoint.Kind.MARKER
		target.target_num = marker.num
		marker_points.append(target)
	body.route_plan.points = marker_points
	check(body.plan_execution.start(body), "A marker-only plan starts on the current road")
	for frame: int in range(1900):
		await tree.physics_frame
	check(body.plan_execution.status == "Plan complete", "Automatic execution visits marker offsets")
	check(body.global_position.z < -69 and body.global_position.z > -74, "Vehicle stops at the final marker rather than the next road node")

	return body

## M captures the road under the actual player; Shift+M creates one two-sided target.
func test_markers() -> bool:
	# Arrange a physical road with an intermediate shape node, plus the real player.
	var old_roads: RoadsLoader = Managers.roads
	var old_player: PlayerHead3D = GlobalState.player
	var old_camera: Camera3D = GlobalState.active_cam
	var loader := RoadsLoader.new()
	Managers.roads = loader
	tree.root.add_child(loader)
	var road: RoadData = RoadMapper.road_from_data_json({"num": 110, "type": "rural_road", "autosmooth": false, "points": [{"pos": [0,0,0]}, {"pos": [0,0,-20]}, {"pos": [0,0,-40]}]})
	road.build_curve()
	loader.storage._list.append(road)
	loader.storage._by_id[110] = road
	var view: RoadWay3D = road.spawn()
	loader.add_child(view)
	loader.storage.add_container(view)
	for frame: int in range(4):
		await tree.process_frame
	var player: Node3D = load("res://scenes/subscenes/player.tscn").instantiate()
	tree.root.add_child(player)
	(player.get_node("Player") as Node3D).global_position = Vector3(1, 0.3, -17.3)
	var tool: MARKER_TOOL = loader.get_child(0) as MARKER_TOOL
	check(tool.placement_at(Vector3(20, 0.3, -17.3)).is_empty(), "Placement rejects positions outside the road")
	check(tool.placement_at(Vector3(-1, 0.3, -17.3)).side == Enums.RoadSide.LEFT, "Placement detects the player's road side")

	# Use the same key handler and confirmation control as gameplay.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_M
	key.pressed = true
	tool._unhandled_key_input(key)
	var dialog: GameDialog = UiState.current_diag
	check(dialog != null and dialog.dialog_key == "RoadMarkerDialog", "M opens the marker naming dialog")
	(dialog.get("_name") as LineEdit).text = "My marker"
	(dialog.get_node("%OkButton") as Button).pressed.emit()
	await tree.process_frame
	check(loader.markers.markers.size() == 1 and loader.markers.markers[0].marker_name == "My marker", "Confirmation stores the chosen marker name")
	check(absf(loader.markers.markers[0].offset - 17.3) < 0.02, "Marker stores the exact road offset, not a nearby shape node")
	key.shift_pressed = true
	tool._unhandled_key_input(key)
	dialog = UiState.current_diag
	(dialog.get_node("%OkButton") as Button).pressed.emit()
	await tree.process_frame
	check(loader.markers.markers.size() == 2 and loader.markers.markers[1].side == Enums.RoadSide.BOTH, "Shift+M creates one BOTH marker")
	check(loader.markers.markers[1].marker_name == "Marker 2", "Unedited marker names use unique numbers")
	check(tool._views[2].get_child_count() == 4, "One BOTH marker has two visual signs")
	check(tool._views[2].get_child(0).scene_file_path == MARKER_TOOL.MARKER_SCENE, "Placed markers use the authored waypoint mesh")
	_check_marker_routing(loader, road)

	# Restore the surrounding session and break fixture resource back-references.
	player.free()
	loader.free()
	for node: RoadNode in road.nodes:
		node.parent_track = null
	Managers.roads = old_roads
	GlobalState.player = old_player
	GlobalState.active_cam = old_camera
	return true

## The graph stays endpoint-only, including after temporary partial-road queries.
func _check_marker_routing(loader: RoadsLoader, road: RoadData) -> void:
	var graph := RoadPathfinder.new()
	graph.build(loader.storage.get_all())
	check(graph.graph_node_count() == 2, "A road contributes endpoints, not intermediate shape nodes")
	var source: RoadRouteAnchor = RoadRouteAnchor.at(road, 35)
	var right: RoadRouteAnchor = loader.markers.markers[0].anchor(loader.storage)
	check(is_equal_approx(graph.path_length(graph.find_path(source, right)), 52.3), "RIGHT marker requires an increasing-order approach")
	var both: RoadRouteAnchor = loader.markers.markers[1].anchor(loader.storage)
	check(absf(graph.path_length(graph.find_path(source, both)) - 17.7) < 0.02, "BOTH marker uses the shorter available approach")
	check(graph.graph_node_count() == 2, "Temporary query anchors do not grow the permanent graph")

	# Route picker exposes named markers, stops and depots, never raw nodes.
	var vehicle := RoadVehicle3D.of("oldtimer_car")
	var script: GDScript = load("res://game/gamescripts/ui/dialogs/road_route/road_route_dialog.gd")
	var dialog: GameDialog = script.create(vehicle)
	tree.root.add_child(dialog)
	var kinds: OptionButton = dialog.get("_kind")
	check(kinds.get_item_id(0) == RoadRoutePoint.Kind.MARKER and dialog.get("_choices").size() == 2, "Route picker defaults to the two named markers")
	for index: int in range(kinds.item_count):
		check(kinds.get_item_id(index) != RoadRoutePoint.Kind.NODE, "Raw nodes cannot be selected as route targets")
	dialog.free()
	vehicle.free()

## Break the fixture's existing road/node/crossing back-reference cycles.
func _cleanup() -> void:
	for road: RoadData in roads.get_all():
		for node: RoadNode in road.nodes:
			node.parent_track = null
			node.cross = null
	for stop: AbstractStation in stops.values():
		stop.connections.parent = null
