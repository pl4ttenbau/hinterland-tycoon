extends Node

var failures: int = 0
var checks: int = 0
var services: WorldServicesCoordinator
var tool: StationCreator
var town: TownData
var road: RoadData
var rail: RailTrackData

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> bool:
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1280, 720)
	check(GameTypes.ensure_initialized() == OK, "Types initialize")
	services = load("res://scenes/subscenes/world_services.tscn").instantiate()
	add_child(services)
	check(services.initialize() == OK, "Services initialize")
	services.world_timer.stop()
	services.passenger_timer.stop()
	check(services.interchanges.load_definitions([]) == OK, "Empty catalog supports new stations")
	services.stations.is_loaded = true
	services.road_stops.is_loaded = true
	GlobalState.station_objs = services.stations.stations_objs
	tool = services.interchanges.get_node("StationCreator")
	town = TownData.of("Test town", Vector2(150, 100))
	town.num = 42
	GlobalState.towns.append(town)
	road = RoadMapper.road_from_data_json({"num": 5, "type": "rural_road", "points": [{"pos": [100, 5, 100]}, {"pos": [500, 5, 100]}]})
	road.build_curve()
	services.roads.storage.add(road)
	rail = RailMapper.rail_track_from_dict({"num": 6, "type": "750_MM", "points": [{"pos": [100, 5, 130]}, {"pos": [500, 5, 130]}]})
	rail.build_curve()
	services.rails.track_storage.add(rail)
	for test: String in ["test_physical_placement", "test_create_and_join", "test_validation", "test_dialogs", "test_multiple_stations", "test_action_dispatch"]:
		if await call(test) != true:
			check(false, test + " aborted")
	services.free()
	check(Managers.interchanges == null and town.stations.is_empty(), "Runtime stops clean up with their session")
	for node: RoadNode in road.nodes:
		node.parent_track = null
	for node: RailNodeData in rail.nodes:
		node.parent_track = null
	GlobalState.towns.erase(town)
	GlobalState.station_objs.clear()
	print("Station creator: %d checks, %d failures" % [checks, failures])
	return true

func test_physical_placement() -> bool:
	var road_view: RoadWay3D = road.spawn()
	services.roads.add_child(road_view)
	services.rails.spawn_rail_track(rail)
	for frame: int in 5:
		await get_tree().process_frame
	await get_tree().physics_frame
	var road_placement: Dictionary = tool.placement_at(Vector3(150, 5.5, 100))
	check(not road_placement.is_empty() and road_placement.domain == "ROAD", "Player's supporting road supplies the anchor")
	var rail_placement: Dictionary = tool.placement_at(Vector3(170, 5.5, 130))
	check(not rail_placement.is_empty() and rail_placement.domain == "RAIL", "Player's supporting rail bedding supplies the anchor")
	check(tool.placement_at(Vector3(150, 20, 100)).is_empty(), "A road far below the player cannot steal placement")
	check(tool.placement_at(Vector3(150, 5.5, 300)).is_empty(), "Off-network placement is rejected")
	return true

func test_create_and_join() -> bool:
	var house := Residence3D.new()
	house.res_bld_obj = ResidenceBuildingData.new(town.num, null)
	add_child(house)
	house.position = Vector3(155, 5, 105)
	town.res_bld_containers.append(house)
	var industry := IndustryData.new(GameTypes.industry_types[0].key, Vector3(160, 5, 110))
	var placement: Dictionary = tool.placement_on(road, Vector3(150, 5, 100))
	check(placement.position.is_equal_approx(Vector3(150, 5, 100)), "Placement retains a point between authored nodes")
	var result: Dictionary = tool.create_stop(placement, -1, "New station", town.num, "", Enums.RoadSide.BOTH)
	check(result.has("stop"), "First stop creates a new interchange")
	if not result.has("stop"):
		return false
	var stop: RoadStationData = result.stop
	check(stop.station_name == "New station" and stop.connected_town == town and town.stations.has(stop), "New interchange owns shared name and town")
	check(services.road_stops.by_num[stop.num] == stop and services.interchanges.stops_by_num[stop.num] == stop, "Runtime road stop is registered in both lookups")
	var bus: BusStop3D = services.road_stops.containers_by_num[stop.num]
	check(bus.get_inventory() != null and bus.get_node("Model").get_child_count() == 2, "BOTH stop has its inventory and two shelters")
	check(bus.global_position.is_equal_approx(stop.position), "Road view is at the selected point")
	var point := RoadRoutePoint.new()
	point.kind = RoadRoutePoint.Kind.STOP
	point.target_num = stop.num
	var anchor: RoadNode = point.resolve(services.roads.storage, services.road_stops.by_num, [])
	check(anchor is RoadRouteAnchor and anchor.position.is_equal_approx(stop.position), "Routing targets the actual stop instead of its nearest node")
	check((anchor as RoadRouteAnchor).arrival_direction == 0, "BOTH permits either approach")
	check(house.res_bld_obj.connected_interchange == stop.interchange and industry.station_connection != null, "Runtime placement refreshes residence and industry catchments")
	check(tool.nearby_interchanges(stop.position + Vector3(50, 0, 0)) == [stop.interchange], "Exactly 50 m joins the existing interchange")
	check(tool.nearby_interchanges(stop.position + Vector3(50.01, 0, 0)).is_empty(), "Beyond 50 m creates a new interchange")
	var rail_placement: Dictionary = tool.placement_on(rail, Vector3(170, 5, 130))
	var joined: Dictionary = tool.create_stop(rail_placement, stop.interchange_num, "Ignored", -1, "STATION_GOODS", Enums.RoadSide.RIGHT)
	check(joined.has("stop"), "Rail stop can join a nearby road interchange")
	if not joined.has("stop"):
		return false
	var rail_stop: RailStationData = joined.stop
	check(rail_stop.interchange == stop.interchange and rail_stop.station_type == "STATION_GOODS", "Joined stop inherits identity and retains its own type")
	check(services.interchanges.interchanges.size() == 1 and stop.num != rail_stop.num, "Joining reuses the parent and allocates a unique stop ID across modes")
	check(rail_stop.node_stations[0].station3d.global_position.is_equal_approx(Vector3(170, 5, 130)), "Rail platform appears at the selected curve position")
	check(services.stations.get_station_3d_with_num(rail_stop.num).get_inventory() != null, "New rail stop has a working inventory")
	check(services.stations.get_station_3d_with_num(rail_stop.num).global_position.is_equal_approx(rail_stop.position), "Rail inventory access is located at the new stop")
	check(road.nodes.size() == 2 and rail.nodes.size() == 2 and rail.nodes[0].station == null, "Placement preserves authored geometry and node station links")
	check(services.interchanges.stop_definitions.is_empty(), "Gameplay does not rewrite the authored catalog")
	check(tool.nearby_interchanges(Vector3(160, 5, 115)).size() == 1, "Several physical stops yield one nearby station entry")
	GlobalState.industries.erase(industry)
	GlobalState.res_blds.erase(house.res_bld_obj)
	town.res_bld_containers.erase(house)
	house.free()
	return true

func test_validation() -> bool:
	var placement: Dictionary = tool.placement_on(road, Vector3(400, 5, 100))
	var count: int = services.interchanges.interchanges.size()
	check(tool.create_stop(placement, -1, " ", town.num, "", Enums.RoadSide.RIGHT).has("error"), "Blank name is rejected")
	check(tool.create_stop(placement, -1, "Orphan", -1, "", Enums.RoadSide.RIGHT).has("error"), "Missing town is rejected")
	check(tool.create_stop(placement, 0, "", -1, "", Enums.RoadSide.RIGHT).has("error"), "Distant interchange cannot be joined")
	check(services.interchanges.interchanges.size() == count, "Failed creation does not publish an empty parent")
	var duplicate: Dictionary = tool.placement_on(road, Vector3(150, 5, 100))
	check(not tool.placement_error(duplicate).is_empty(), "Duplicate placement is rejected")
	var stale: Dictionary = placement.duplicate()
	stale.offset = 10000.0
	check(not tool.placement_error(stale).is_empty(), "Outdated infrastructure anchors are rejected")
	return true

func test_dialogs() -> bool:
	var script: GDScript = load("res://game/gamescripts/ui/dialogs/station_creator/station_creator_dialog.gd")
	if script == null or not script.can_instantiate():
		return false
	var placement: Dictionary = tool.placement_on(road, Vector3(400, 5, 100))
	var before: int = services.interchanges.stops_by_num.size()
	var previous_blocked: bool = UiState.movement_blocked
	var dialog: ModalGameDialog = script.create(tool, placement)
	add_child(dialog)
	check(dialog.dialog_key == "CreateStationDialog" and dialog.get_node("%OkButton").text == "Create station", "No nearby stop opens the new-station menu")
	await capture_preview(dialog, "create")
	check(UiState.movement_blocked, "Dialog suspends world input")
	dialog.close_all()
	await get_tree().process_frame
	check(services.interchanges.stops_by_num.size() == before and UiState.movement_blocked == previous_blocked and UiState.current_diag == null, "Cancel makes no stop and restores input")
	dialog = script.create(tool, placement)
	add_child(dialog)
	dialog.get_node("%OkButton").pressed.emit()
	await get_tree().process_frame
	check(services.interchanges.stops_by_num.size() == before + 1, "Confirm creates a station through the actual dialog")
	placement = tool.placement_on(road, Vector3(420, 5, 100))
	dialog = script.create(tool, placement)
	add_child(dialog)
	check(dialog.dialog_key == "AddStationStopDialog" and dialog.get_node("%OkButton").text == "Add stop", "Nearby stop opens the add-stop menu")
	check(dialog.find_child("StationName", true, false) == null, "Existing station dialog does not rename the interchange")
	await capture_preview(dialog, "add")
	dialog.get_node("%OkButton").pressed.emit()
	await get_tree().process_frame
	check(services.interchanges.stops_by_num.size() == before + 2 and services.interchanges.interchanges.size() == 2, "Add-stop dialog reuses the existing parent")
	var menu: RadialActionMenu = load("res://scenes/ui/radial_menu/radial_action_menu.tscn").instantiate()
	check(menu.available_actions().any(func(item: Dictionary): return item.id == "CreateStop"), "Loaded session offers Create stop in the action menu")
	menu.free()
	return true

func test_multiple_stations() -> bool:
	var placement: Dictionary = tool.placement_on(road, Vector3(250, 5, 100))
	var created: Dictionary = tool.create_stop(placement, -1, "Another station", town.num, "", Enums.RoadSide.LEFT)
	check(created.has("stop"), "A separate station can be created beyond every existing stop's 50 m radius")
	if not created.has("stop"):
		return false
	placement = tool.placement_on(road, Vector3(210, 5, 100))
	var nearby: Array[InterchangeData] = tool.nearby_interchanges(placement.origin)
	check(nearby.size() == 2 and nearby[0] == created.stop.interchange, "Nearby stations are deduplicated and ordered by closest stop")
	var script: GDScript = load("res://game/gamescripts/ui/dialogs/station_creator/station_creator_dialog.gd")
	var dialog: ModalGameDialog = script.create(tool, placement)
	add_child(dialog)
	var selector: OptionButton = dialog.find_child("ExistingStation", true, false)
	check(selector != null and selector.item_count == 2 and selector.selected == 0, "Ambiguous placement offers both stations, with nearest selected")
	dialog.close_all()
	await get_tree().process_frame
	return true

func test_action_dispatch() -> bool:
	var player_scene: Node3D = load("res://scenes/subscenes/player.tscn").instantiate()
	var body: BasicFpsPlayer = player_scene.get_node("Player")
	body.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(player_scene)
	body.global_position = Vector3(300, 5.5, 100)
	var player: PlayerHead3D = GlobalState.player
	var handler := ActionHandler.new()
	add_child(handler)
	var before: int = services.interchanges.stops_by_num.size()
	check(handler._on_action_triggered("CreateStop"), "Action captures a real player's supporting road and opens the dialog")
	check(UiState.current_diag != null and body.process_mode == Node.PROCESS_MODE_DISABLED, "Creator dialog suspends the walking player")
	check(not handler._on_action_triggered("CreateStop"), "Repeated dispatch cannot open a duplicate dialog")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	UiState.current_diag._input(escape)
	await get_tree().process_frame
	check(body.process_mode == Node.PROCESS_MODE_WHEN_PAUSED and services.interchanges.stops_by_num.size() == before, "Escape restores the exact player process mode without creating a stop")
	var menu: RadialActionMenu = load("res://scenes/ui/radial_menu/radial_action_menu.tscn").instantiate()
	var vehicle := RoadVehicle3D.new()
	player.in_road_vehicle = vehicle
	check(not menu.available_actions().any(func(item: Dictionary): return item.id == "CreateStop"), "Create stop is hidden inside a road vehicle")
	check(not handler._on_action_triggered("CreateStop"), "Dispatcher rechecks vehicle occupancy")
	player.in_road_vehicle = null
	vehicle.free()
	menu.free()
	GlobalState.player = null
	GlobalState.active_cam = null
	player_scene.free()
	handler.free()
	return true

func capture_preview(dialog: Control, kind: String) -> void:
	for frame: int in 3:
		await get_tree().process_frame
	var panel: Control = dialog.get_node("OuterPanel")
	check(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), "Dialog fits the viewport: " + kind)
	if "--station-preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/station-creator-%s.png" % kind)
