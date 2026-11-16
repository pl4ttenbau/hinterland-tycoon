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
	for test: String in ["test_physical_placement", "test_create_and_join", "test_validation", "test_dialogs", "test_multiple_stations", "test_action_dispatch", "test_track_spending", "test_rail_confirmation"]:
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
	var result: Dictionary = tool.create_stop(placement, -1, "New station", town.num, "", Enums.RoadStopDirection.BOTH_DIRECTIONS)
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
	var joined: Dictionary = tool.create_stop(rail_placement, stop.interchange_num, "Ignored", -1, "STATION_GOODS", Enums.RoadStopDirection.ROAD_NODES_INCREASE)
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
	check(tool.create_stop(placement, -1, " ", town.num, "", Enums.RoadStopDirection.ROAD_NODES_INCREASE).has("error"), "Blank name is rejected")
	check(tool.create_stop(placement, -1, "Orphan", -1, "", Enums.RoadStopDirection.ROAD_NODES_INCREASE).has("error"), "Missing town is rejected")
	check(tool.create_stop(placement, 0, "", -1, "", Enums.RoadStopDirection.ROAD_NODES_INCREASE).has("error"), "Distant interchange cannot be joined")
	check(services.interchanges.interchanges.size() == count, "Failed creation does not publish an empty parent")
	var duplicate: Dictionary = tool.placement_on(road, Vector3(150, 5, 100))
	check(not tool.placement_error(duplicate).is_empty(), "Duplicate placement is rejected")
	var stale: Dictionary = placement.duplicate()
	stale.offset = 10000.0
	check(not tool.placement_error(stale).is_empty(), "Outdated infrastructure anchors are rejected")
	return true

func test_dialogs() -> bool:
	var placement: Dictionary = tool.placement_on(road, Vector3(400, 5, 99), Vector3.LEFT)
	var before: int = services.interchanges.stops_by_num.size()
	var previous_blocked: bool = UiState.movement_blocked
	var dialog: ModalGameDialog = StationCreatorDialog.create(tool, placement)
	add_child(dialog)
	check(dialog.dialog_key == "CreateStationDialog" and dialog.get_node("%OkButton").text == "Create station · DM 5,000.00", "No nearby stop opens the new-station menu")
	var sides: OptionButton = dialog.get_node("%RoadSide")
	check(sides.get_item_text(sides.selected) == "Right"
		and sides.get_selected_id() == Enums.RoadStopDirection.ROAD_NODES_DECREASE,
		"Looking back along the road makes the decreasing shelter the player's right")
	var preview := dialog.get_node("RoadPlacementPreview") as Node3D
	check(preview.get_node("ReverseShelter").visible and not preview.get_node("ForwardShelter").visible,
		"Only the selected shelter is previewed initially")
	sides.select(2)
	sides.item_selected.emit(sides.selected)
	check(preview.get_node("ReverseShelter").visible and preview.get_node("ForwardShelter").visible,
		"Both sides previews two shelters")
	await capture_preview(dialog, "create")
	check(UiState.movement_blocked, "Dialog suspends world input")
	dialog.close_all()
	await get_tree().process_frame
	check(not is_instance_valid(preview) and services.interchanges.stops_by_num.size() == before
		and UiState.movement_blocked == previous_blocked and UiState.current_diag == null,
		"Cancel removes the preview, makes no stop, and restores input")
	dialog = StationCreatorDialog.create(tool, tool.placement_on(road, placement.origin, Vector3.RIGHT))
	add_child(dialog)
	sides = dialog.get_node("%RoadSide")
	check(sides.get_item_text(sides.selected) == "Left"
		and sides.get_selected_id() == Enums.RoadStopDirection.ROAD_NODES_DECREASE,
		"Turning around changes the label while keeping the default shelter on the player's side of the road")
	sides.select(1)
	sides.item_selected.emit(sides.selected)
	preview = dialog.get_node("RoadPlacementPreview")
	var forward: Node3D = preview.get_node("ForwardShelter")
	var expected_transform: Transform3D = forward.global_transform
	var geometry: MeshInstance3D = forward.find_children("*", "MeshInstance3D", true, false)[0]
	var material := geometry.material_override as StandardMaterial3D
	check(forward.visible and not preview.get_node("ReverseShelter").visible
		and material.albedo_color.is_equal_approx(Color("#39c962")),
		"Changing sides swaps the green shelter preview")
	var next_stop_num: int = services.interchanges.next_stop_num()
	dialog.get_node("%OkButton").pressed.emit()
	await get_tree().process_frame
	check(services.interchanges.stops_by_num.size() == before + 1, "Confirm creates a station through the actual dialog")
	var created: RoadStationData = services.interchanges.stops_by_num.get(next_stop_num)
	check(created != null and created.direction == Enums.RoadStopDirection.ROAD_NODES_INCREASE, "The created stop keeps the direction for the selected side")
	var view: BusStop3D = services.road_stops.containers_by_num.get(next_stop_num)
	var shelter: Node3D = view.get_node("Model/Shelter")
	check(shelter.global_transform.is_equal_approx(expected_transform), "The finished shelter matches the preview position and rotation")
	placement = tool.placement_on(road, Vector3(420, 5, 100))
	dialog = StationCreatorDialog.create(tool, placement)
	add_child(dialog)
	check(dialog.dialog_key == "AddStationStopDialog" and dialog.get_node("%OkButton").text == "Add stop · DM 5,000.00", "Nearby stop opens the add-stop menu")
	check(not dialog.get_node("%StationName").is_visible_in_tree(), "Existing station dialog does not rename the interchange")
	await capture_preview(dialog, "add")
	dialog.get_node("%OkButton").pressed.emit()
	await get_tree().process_frame
	check(services.interchanges.stops_by_num.size() == before + 2 and services.interchanges.interchanges.size() == 2, "Add-stop dialog reuses the existing parent")
	var menu: RadialActionMenu = load("res://scenes/ui/radial_menu/radial_action_menu.tscn").instantiate()
	check(menu.available_actions().any(func(item: Dictionary): return item.id == "CreateStop"), "Loaded session offers Create stop in the action menu")
	menu.free()
	return true

func test_rail_confirmation() -> bool:
	var placement: Dictionary = tool.placement_on(rail, Vector3(270, 5, 130))
	var before: int = services.interchanges.stops_by_num.size()
	var player: PlayerAvatar = load("res://scenes/subscenes/player.tscn").instantiate()
	player.walking_body.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(player)
	player.walking_body.global_position = Vector3(270, 5.5, 130)
	var handler := ActionHandler.new()
	add_child(handler)
	var cash: int = player.company.cash
	var menu: RadialActionMenu = load("res://scenes/ui/radial_menu/radial_action_menu.tscn").instantiate()
	check(menu.available_actions().any(func(item: Dictionary): return item.title == "Build platform"),
		"The radial action says Build platform on the track")
	menu.free()
	var opened: bool = handler._on_action_triggered("CreateStop")
	var dialog := UiState.current_diag as StationCreatorDialog
	check(opened and dialog != null, "Create stop opens the rail confirmation while standing on the track")
	if dialog == null:
		_free_placement_player(player, handler)
		return false
	var preview := dialog.get_node("RailPlacementPreview") as Node3D
	var visual := preview.get_node("PlatformModel") as BuildingMesh3D
	var model := visual.get_child(0) as MeshInstance3D
	var tint := model.material_override as StandardMaterial3D
	var transform: Transform3D = preview.global_transform
	check(visual.transform.is_equal_approx(Transform3D.IDENTITY), "Passenger mesh scene starts at identity")
	check(tint.albedo_color.is_equal_approx(Color("#39c962")) and transform.origin.is_equal_approx(placement.position),
		"Rail confirmation shows the green platform at the track position")
	var yes: Button = dialog.get_node("%OkButton")
	var no: Button = yes.get_parent().get_child(1)
	check(yes.text.begins_with("Yes") and no.text == "No", "Rail construction offers Yes and No")
	no.pressed.emit()
	await get_tree().process_frame
	check(not is_instance_valid(preview) and services.interchanges.stops_by_num.size() == before
		and player.company.cash == cash, "No clears the preview without placing or charging for the stop")
	handler._on_action_triggered("CreateStop")
	dialog = UiState.current_diag as StationCreatorDialog
	if dialog == null:
		_free_placement_player(player, handler)
		return false
	preview = dialog.get_node("RailPlacementPreview")
	var side := dialog.find_child("PlatformSide", true, false) as OptionButton
	side.select(side.get_item_index(RailStationData.PlatformSide.LEFT))
	side.item_selected.emit(side.selected)
	check(preview.global_position.is_equal_approx(transform.origin) and preview.global_basis.z.dot(transform.basis.z) < -0.99,
		"Left flips the platform without moving the stop")
	transform = preview.global_transform
	var types := dialog.find_child("PlatformType", true, false) as OptionButton
	types.select(1)
	types.item_selected.emit(types.selected)
	visual = preview.get_node("PlatformModel")
	model = visual.get_child(0)
	var cargo: StationBuildingCatalog = StationBuildingCatalog.rail_platform("STATION_GOODS")
	check(visual.scene_file_path == cargo.preview_scene.resource_path
		and visual.transform.is_equal_approx(Transform3D.IDENTITY)
		and preview.global_transform.is_equal_approx(transform)
		and (model.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("#39c962")),
		"Cargo swaps to its green BuildingMesh3D preview without resetting the selected side")
	var preview_mesh_transform: Transform3D = model.global_transform
	var next_stop: int = services.interchanges.next_stop_num()
	dialog.get_node("%OkButton").pressed.emit()
	await get_tree().process_frame
	var stop := services.interchanges.stops_by_num.get(next_stop) as RailStationData
	check(stop != null and not is_instance_valid(dialog) and player.company.cash == cash - CompanyData.STOP_COST,
		"Yes places the rail stop, charges once and closes the preview")
	if stop == null:
		_free_placement_player(player, handler)
		return false
	var link: NodeStationLink3D = stop.node_stations[0].station3d
	var building := link.get_node("StationBuilding3D") as RailPlatform3D
	var built_model := building.platform_mesh.get_child(0) as MeshInstance3D
	check(stop.station_type == "STATION_GOODS" and building.scene_file_path == cargo.building_scene.resource_path
		and building.platform_mesh.scene_file_path == cargo.preview_scene.resource_path
		and built_model.global_transform.is_equal_approx(preview_mesh_transform),
		"The Cargo choice places the matching RailPlatform3D and mesh at the preview transform")
	await get_tree().physics_frame
	var body := building.get_node("StationBody") as StationCollider
	for sample: Vector3 in [Vector3(0, 1.1, -5.4), Vector3(13, 0.54, -5.4)]:
		var surface: Vector3 = building.to_global(sample)
		var query := PhysicsRayQueryParameters3D.create(surface + Vector3.UP * 2.0, surface - Vector3.UP * 2.0, 1)
		var hit: Dictionary = building.get_world_3d().direct_space_state.intersect_ray(query)
		check(hit.get("collider") == body and absf(hit.position.y - surface.y) < 0.08,
			"Cargo collision follows the visible deck and sloped ramp")
	check(body.get_stop() == stop, "The cargo platform collider opens its station information")
	var duplicate: Dictionary = tool.placement_on(rail, Vector3(290, 5, 130))
	var rejected: Dictionary = tool.create_stop(duplicate, stop.interchange_num, "", -1, "STATION_PASS", Enums.RoadStopDirection.ROAD_NODES_INCREASE)
	check(rejected.has("error") and rejected.error.contains("already has a platform")
		and player.company.cash == cash - CompanyData.STOP_COST,
		"The same interchange cannot buy another platform on this track")

	player.walking_body.global_position = Vector3(485, 5.5, 130)
	handler._on_action_triggered("CreateStop")
	dialog = UiState.current_diag as StationCreatorDialog
	if dialog == null:
		_free_placement_player(player, handler)
		return false
	preview = dialog.get_node("RailPlacementPreview")
	var hide_option := dialog.find_child("HidePlatform", true, false) as CheckBox
	hide_option.button_pressed = true
	check(not preview.get_node("PlatformModel").visible and preview.get_node("StopMarker").visible,
		"Hiding the platform shows the stopping point in the preview")
	next_stop = services.interchanges.next_stop_num()
	dialog.get_node("%OkButton").pressed.emit()
	await get_tree().process_frame
	_free_placement_player(player, handler)
	var hidden := services.interchanges.stops_by_num.get(next_stop) as RailStationData
	if hidden == null:
		return false
	var hidden_link: NodeStationLink3D = hidden.node_stations[0].station3d
	var hidden_shape := hidden_link.get_node("StationBuilding3D/StationBody/StationShape3D") as CollisionShape3D
	check(hidden.interchange != stop.interchange and hidden.hide_building and hidden_shape.disabled
		and not hidden_link.get_node("StationBuilding3D").visible and hidden_link.get_node("StationSign3D").visible,
		"A different interchange may build a hidden stop on the same track with its sign and without collision")
	return true

func _free_placement_player(player: PlayerAvatar, handler: ActionHandler) -> void:
	GlobalState.player = null
	GlobalState.active_cam = null
	player.free()
	handler.free()


func test_multiple_stations() -> bool:
	var placement: Dictionary = tool.placement_on(road, Vector3(250, 5, 100))
	var created: Dictionary = tool.create_stop(placement, -1, "Another station", town.num, "", Enums.RoadStopDirection.ROAD_NODES_DECREASE)
	check(created.has("stop"), "A separate station can be created beyond every existing stop's 50 m radius")
	if not created.has("stop"):
		return false
	placement = tool.placement_on(road, Vector3(210, 5, 100))
	var nearby: Array[InterchangeData] = tool.nearby_interchanges(placement.origin)
	check(nearby.size() == 2 and nearby[0] == created.stop.interchange, "Nearby stations are deduplicated and ordered by closest stop")
	var dialog: ModalGameDialog = StationCreatorDialog.create(tool, placement)
	add_child(dialog)
	var selector: OptionButton = dialog.find_child("ExistingStation", true, false)
	check(selector != null and selector.item_count == 2 and selector.selected == 0, "Ambiguous placement offers both stations, with nearest selected")
	dialog.close_all()
	await get_tree().process_frame
	return true

func test_action_dispatch() -> bool:
	var player_scene: PlayerAvatar = load("res://scenes/subscenes/player.tscn").instantiate()
	var body: BasicFpsPlayer = player_scene.walking_body
	body.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(player_scene)
	body.global_position = Vector3(300, 5.5, 100)
	var player: PlayerAvatar = GlobalState.player
	var handler := ActionHandler.new()
	add_child(handler)
	var before: int = services.interchanges.stops_by_num.size()
	player.walking_camera.look_at(player.walking_camera.global_position + Vector3.LEFT)
	check(handler._on_action_triggered("CreateStop"), "Action captures a real player's supporting road and opens the dialog")
	check(UiState.current_diag != null and body.process_mode == Node.PROCESS_MODE_DISABLED, "Creator dialog suspends the walking player")
	var road_side: OptionButton = UiState.current_diag.get_node("%RoadSide")
	check(road_side.get_item_id(1) == Enums.RoadStopDirection.ROAD_NODES_DECREASE,
		"The real action maps Right from the walking camera's view")
	check(not handler._on_action_triggered("CreateStop"), "Repeated dispatch cannot open a duplicate dialog")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	UiState.current_diag._input(escape)
	await get_tree().process_frame
	check(body.process_mode == Node.PROCESS_MODE_WHEN_PAUSED and services.interchanges.stops_by_num.size() == before, "Escape restores the exact player process mode without creating a stop")
	var placement: Dictionary = tool.placement_on(road, Vector3(300, 5, 100))
	player.company.cash = 4_999
	var rejected: Dictionary = tool.create_stop(placement, 0, "", -1, "", Enums.RoadStopDirection.BOTH_DIRECTIONS)
	check(rejected.has("error") and rejected.error.contains("Insufficient funds")
		and services.interchanges.stops_by_num.size() == before and player.company.cash == 4_999,
		"An unaffordable stop leaves cash and infrastructure unchanged")
	player.company.cash = 5_000
	var nearby: Array[InterchangeData] = tool.nearby_interchanges(placement.origin)
	var created: Dictionary = tool.create_stop(placement, nearby[0].num, "", -1, "", Enums.RoadStopDirection.BOTH_DIRECTIONS)
	check(created.has("stop") and player.company.cash == 0, "A successful stop charges the company once")
	var menu: RadialActionMenu = load("res://scenes/ui/radial_menu/radial_action_menu.tscn").instantiate()
	var vehicle := RoadVehicle3D.of("trabant_601_green")
	vehicle.freeze = true
	add_child(vehicle)
	check(player.control.enter_road_vehicle(vehicle), "Fixture boards the road vehicle")
	check(not menu.available_actions().any(func(item: Dictionary): return item.id == "CreateStop"), "Create stop is hidden inside a road vehicle")
	check(not handler._on_action_triggered("CreateStop"), "Dispatcher rechecks vehicle occupancy")
	player.control.exit_vehicle()
	vehicle.free()
	menu.free()
	GlobalState.player = null
	GlobalState.active_cam = null
	player_scene.free()
	handler.free()
	return true

func test_track_spending() -> bool:
	var player := PlayerAvatar.new()
	GlobalState.player = player
	var fork := NewRailForkData.new(Vector3(500, 5, 130))
	UiState.build_infr_mode = UiModeBuildInfr.from_fork(fork)
	var builder: NewRailBuilder = services.rail_builder
	builder._on_ui_mode_changed(Enums.UiMode.BUILD_INFR)
	check(builder.curr_track3d == null and player.company.cash == CompanyData.STARTING_CASH,
		"Entering rail build mode does not place or charge for track")
	player.company.cash = 500
	builder._on_terrain_click(Vector3(520, 5, 130))
	var track: RailTrack3D = builder.curr_track3d
	check(track != null and track.track.nodes.size() == 2 and player.company.cash == 0,
		"Adding a rail segment consumes the quoted price")
	builder._on_terrain_click(Vector3(540, 5, 130))
	check(track.track.nodes.size() == 2 and player.company.cash == 0,
		"An unaffordable rail segment is rejected")
	builder._on_ui_mode_changed(Enums.UiMode.WALKING)
	UiState.build_infr_mode = null
	GlobalState.outer_tracks.erase(track)
	for node: RailNodeData in track.track.nodes:
		node.parent_track = null
	track.free()
	GlobalState.player = null
	player.free()
	fork.setting.parent = null
	return true


func capture_preview(dialog: Control, kind: String) -> void:
	for frame: int in 3:
		await get_tree().process_frame
	var panel: Control = dialog.get_node("OuterPanel")
	check(get_viewport().get_visible_rect().encloses(panel.get_global_rect()), "Dialog fits the viewport: " + kind)
	if "--station-preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/station-creator-%s.png" % kind)
