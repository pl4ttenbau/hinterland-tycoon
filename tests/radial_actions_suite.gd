## Exercise the actual menu, dispatcher and addon fork without spawning a map.
extends Node

class CountingAction extends BaseAction:
	var calls := 0
	func on_trigger() -> void:
		calls += 1

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func quit(code: int) -> void:
	get_tree().quit(code)

func _ids(menu: RadialActionMenu) -> Array:
	return menu.available_actions().map(func(item: Dictionary): return item.id)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().root.size = Vector2i(1280, 720)
	check(GameTypes.ensure_initialized() == OK, "Vehicle types initialize")
	var root: Window = get_tree().root
	var old_vehicles: VehiclePlacer = Managers.vehicles
	var old_roads: RoadsLoader = Managers.roads
	var old_rails: RailsLoader = Managers.rails
	var old_player: PlayerAvatar = GlobalState.player
	var old_camera := GlobalState.active_cam
	var old_mouse := Input.mouse_mode
	var old_trains: Array[Train3D] = GlobalState.trains
	var old_main_menu: bool = UiState.in_main_menu
	var old_blocked: bool = UiState.movement_blocked
	var vehicles := VehiclePlacer.new()
	var roads := RoadsLoader.new()
	var rails := RailsLoader.new()
	var player: PlayerAvatar = load("res://scenes/subscenes/player.tscn").instantiate()
	player.walking_body.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(player)
	Managers.vehicles = vehicles
	Managers.roads = roads
	Managers.rails = rails
	GlobalState.player = player
	GlobalState.trains = []
	UiState.in_main_menu = false
	UiState.movement_blocked = false
	var scene: PackedScene = load("res://scenes/ui/radial_menu/radial_action_menu.tscn")
	if scene == null:
		quit(1)
		return
	var menu := scene.instantiate() as RadialActionMenu
	root.add_child(menu)
	check("Company" in _ids(menu) and "Game Menu" in _ids(menu), "Both new menu dialogs are offered on foot")
	check("Prospect" in _ids(menu), "Prospect is offered on foot")
	check("Build" in _ids(menu), "Build is offered in the circular menu")
	check("RoadMarker" in _ids(menu) and "AutoRoute" not in _ids(menu), "Walking offers marker, not auto-routing")
	check("Enter" not in _ids(menu), "No train entry when train list is empty")
	for unsupported: String in ["Place"]:
		check(unsupported not in _ids(menu), "Unimplemented action is not shown: " + unsupported)
	var road_vehicle := RoadVehicle3D.of("trabant_601_green")
	road_vehicle.freeze = true
	add_child(road_vehicle)
	check(player.control.enter_road_vehicle(road_vehicle), "Fixture boards a road vehicle")
	check("Company" in _ids(menu) and "Game Menu" in _ids(menu), "Both new menu dialogs remain available inside a vehicle")
	check("Prospect" in _ids(menu), "Prospect remains in the road-vehicle menu")
	check("AutoRoute" in _ids(menu) and "Enter" in _ids(menu), "Occupied road vehicle offers routing and exit")
	check("RoadMarker" not in _ids(menu) and "Connect" not in _ids(menu), "Road vehicle hides on-foot actions")
	var train := Train3D.new()
	var locomotive := Vehicle3D.new()
	locomotive.train3d = train
	train.locomotive = locomotive
	var train_camera := Camera3D.new()
	train_camera.name = "Camera3D"
	locomotive.add_child(train_camera)
	train_camera.owner = locomotive
	train.add_child(locomotive)
	add_child(train)
	var collider := VehicleCollider.new()
	locomotive.add_child(collider)
	var click_handler := BaseEntityClickHandler.new()
	add_child(click_handler)
	check(click_handler.handle_click(collider), "Train click switches from road vehicle to train")
	check(not road_vehicle.player_driving and player.control.current_train() == train and GlobalState.active_cam == train_camera, "Switching targets releases the old driver and changes the camera")
	click_handler.free()
	collider.free()
	check("AutoRoute" not in _ids(menu) and "RoadMarker" not in _ids(menu), "Train occupancy does not expose road actions")
	check("Prospect" in _ids(menu), "Prospect remains in the train menu")
	var control: Control = menu.get_node("%RadialMenu")
	control.set_items(menu.available_actions())
	check(control.get_node("ItemIcons").get_child_count() == 6, "Changing context rebuilds icon nodes")
	check(is_equal_approx(control.item_angle * 6, control.circle_coverage * TAU), "Changing context recalculates segment geometry")
	var enter_action := EnterAction.new()
	add_child(enter_action)
	enter_action.on_trigger()
	check(not player.control.is_in_vehicle() and GlobalState.active_cam == player.walking_camera, "Enter exits the train through player control")
	check(player.walking_position().is_equal_approx(train_camera.global_position + Vector3(12, -1, 0)), "Train exit preserves the walking placement offset")
	GlobalState.trains.append(train)
	var interact := InputEventKey.new()
	interact.physical_keycode = KEY_E
	interact.pressed = true
	UiState.movement_blocked = true
	enter_action._unhandled_key_input(interact)
	check(not player.control.is_in_vehicle(), "A blocked UI prevents keyboard boarding")
	UiState.movement_blocked = false
	enter_action._unhandled_key_input(interact)
	check(player.control.current_train() == train, "The vehicle key boards the available train through player control")
	UiState.block_world_input(menu)
	var overlay: ModalGameDialog = load("res://scenes/ui/dialogs/game_menu/game_menu_dialog.tscn").instantiate()
	add_child(overlay)
	UiState.release_world_input(menu)
	check(UiState.movement_blocked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Releasing one input owner leaves the modal in control")
	train.free()
	check(not player.control.is_in_vehicle() and player.walking_body.process_mode == Node.PROCESS_MODE_DISABLED, "Vehicle deletion preserves the modal's walking suspension")
	overlay.close_all()
	await get_tree().process_frame
	check(player.walking_body.process_mode == Node.PROCESS_MODE_WHEN_PAUSED and GlobalState.active_cam == player.walking_camera, "Closing the modal restores walking after the occupied train is deleted")
	GlobalState.trains.clear()
	enter_action.free()
	var handler := ActionHandler.new()
	var action := CountingAction.new()
	action.name = "ConnectAction"
	action.key = "Connect"
	handler.add_child(action)
	root.add_child(handler)
	menu.action_requested.connect(handler._on_action_triggered)
	check(handler._on_action_triggered("Connect") and action.calls == 1, "Connect dispatches exactly once")
	check(not handler._on_action_triggered("Unknown"), "Unknown action is rejected")
	check(not handler._on_action_triggered("AutoRoute"), "Routing rechecks vehicle occupancy at dispatch")
	check(not handler._on_action_triggered("RoadMarker"), "No marker action when no session placement tool is present")
	GlobalState.player = null
	for action_key: String in ["Game Menu", "Company"]:
		var previous_mouse_mode := Input.mouse_mode
		var previous_blocked := UiState.movement_blocked
		check(handler._on_action_triggered(action_key), "Menu action opens its dialog: " + action_key)
		var dialog: GameDialog = UiState.current_diag
		var expected_key := "GameMenuDialog" if action_key == "Game Menu" else "CompanyInfoDialog"
		check(is_instance_valid(dialog) and dialog.dialog_key == expected_key, "Correct named dialog is registered")
		check(dialog.get_node("%Content").get_child_count() == 0, "Dialog content is intentionally empty")
		check(UiState.movement_blocked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Dialog suspends world input")
		check(not handler._on_action_triggered(action_key), "Cannot open a duplicate dialog")
		dialog.get_node("%OkButton").pressed.emit()
		await get_tree().process_frame
		check(UiState.current_diag == null and UiState.movement_blocked == previous_blocked and Input.mouse_mode == previous_mouse_mode, "Close button restores previous input state")
		check(handler._on_action_triggered(action_key), "Dialog can be reopened")
		dialog = UiState.current_diag
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		dialog._input(escape)
		await get_tree().process_frame
		check(UiState.current_diag == null and UiState.movement_blocked == previous_blocked, "Escape closes the dialog and restores input")
	GlobalState.player = player
	await _test_dialog_lifecycle()
	await _test_train_composition()
	await _test_prospect(menu, handler, road_vehicle)

	# Open/short release must remain available to click; long release activates once.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	var mouse_mode := Input.mouse_mode
	menu.position = Vector2(97, 61)
	menu._input(press)
	var radial: Control = menu.get_node("%RadialMenu")
	check(radial.visible and UiState.movement_blocked, "Open captures world input")
	check(radial.show_animation and radial.modulate.a < 1.0, "Opening begins with a fade")
	check((radial.global_position + radial.center_offset).distance_to(menu.get_viewport_rect().size / 2.0) < 1.0, "Fan animation starts anchored to the screen centre")
	if radial.tween.is_running():
		await radial.tween.finished
	check(radial.state == radial.MenuState.open and is_equal_approx(radial.modulate.a, 1.0), "Opening animation finishes visible")
	check((radial.global_position + radial.center_offset).distance_to(menu.get_viewport_rect().size / 2.0) < 1.0, "Menu stays centred after layout and animation")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	radial.msecs_at_opened = Time.get_ticks_msec()
	menu._input(release)
	radial._radial_input(release)
	check(radial.visible and UiState.movement_blocked, "A short right release keeps the menu open for a selection")
	radial.set_selected_item(0)
	handler.remove_child(action)
	action.free()
	radial.msecs_at_opened = Time.get_ticks_msec() - 500
	var selections: Array = []
	radial.item_selected.connect(func(id: Variant, _position: Vector2): selections.append(id))
	radial._handle_mouse_buttons(release)
	check(selections.size() == 1, "Held-right release emits exactly one selection")
	check(not UiState.movement_blocked and Input.mouse_mode == mouse_mode, "Close restores input state before dispatch")
	if radial.tween.is_running():
		await radial.tween.finished
	check(not radial.visible, "Close animation finishes hidden")
	for item: Dictionary in menu.available_actions():
		check(item.texture != null, "Action has a distinct loadable icon: " + str(item.id))
	UiState.in_main_menu = true
	menu._input(press)
	check(not radial.visible, "Main menu cannot open gameplay actions")
	UiState.in_main_menu = false
	menu._input(press)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	radial._radial_input(cancel)
	if radial.tween.is_running():
		await radial.tween.finished
	check(not radial.visible and not UiState.movement_blocked, "Escape cancels even during opening and restores input")
	# Prevent the deferred selected action from operating on test doubles.
	handler.free()
	menu.free()
	await get_tree().process_frame
	Managers.vehicles = old_vehicles
	Managers.roads = old_roads
	Managers.rails = old_rails
	GlobalState.player = old_player
	GlobalState.active_cam = old_camera
	Input.mouse_mode = old_mouse
	GlobalState.trains = old_trains
	UiState.in_main_menu = old_main_menu
	UiState.movement_blocked = old_blocked
	player.free()
	road_vehicle.free()
	vehicles.free()
	roads.free()
	rails.free()
	print("Radial actions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_dialog_lifecycle() -> void:
	var shell: PackedScene = load("res://scenes/ui/dialogs/game_menu/game_menu_dialog.tscn")
	var outer := shell.instantiate() as ModalGameDialog
	check(UiState.current_diag == null, "An off-tree dialog leaves gameplay input alone")
	add_child(outer)
	var inner := shell.instantiate() as ModalGameDialog
	add_child(inner)
	var results: Array = []
	inner.closed.connect(func(result: Variant): results.append(result))
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	outer._input(escape)
	check(not outer.is_queued_for_deletion() and UiState.current_diag == inner, "Only the top dialog accepts Escape")
	inner._input(escape)
	inner.close_all()
	check(results.size() == 1 and results[0] == null, "Repeated close requests emit one cancellation result")
	await get_tree().process_frame
	check(UiState.current_diag == outer and UiState.movement_blocked, "Closing the top dialog restores the underlying modal")
	outer.free()
	check(UiState.current_diag == null and not UiState.movement_blocked, "Direct removal also releases the modal")


func _test_train_composition() -> void:
	var spawn_action := SpawnAction.new()
	add_child(spawn_action)
	var dialog := spawn_action.show_compose_train_diag()
	check(UiState.current_diag == dialog and UiState.movement_blocked, "Train composition uses the shared modal lifecycle")
	var catalog := dialog.get_node("%AddableVehiclesList") as VehicleListUi
	var add := dialog.get_node("%AddVehicleButton") as Button
	for key: String in ["loco_faur", "wismar_railbus"]:
		catalog.selection_changed.emit(key)
		add.pressed.emit()
	await get_tree().process_frame
	var list := dialog.get_node("%TrainVehicleList")
	var second := list.get_child(2) as TrainCompositionVehicleRow
	(second.get_node("%BtnUp") as Button).pressed.emit()
	check(dialog.vehicle_rows.rows[0].veh_type_key == "wismar_railbus", "The row moves up in the draft")
	await get_tree().process_frame
	var first := list.get_child(1) as TrainCompositionVehicleRow
	(first.get_node("%BtnDown") as Button).pressed.emit()
	check(dialog.vehicle_rows.rows[0].veh_type_key == "loco_faur", "The row moves down in the draft")
	await get_tree().process_frame
	first = list.get_child(1) as TrainCompositionVehicleRow
	(first.get_node("%BtnRemove") as Button).pressed.emit()
	check(dialog.vehicle_rows.rows.size() == 1 and dialog.vehicle_rows.rows[0].index == 0, "Removing a row reindexes the draft")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	dialog._input(escape)
	await get_tree().process_frame
	check(UiState.current_diag == null and not UiState.movement_blocked, "Cancel closes the composition and releases gameplay input")
	spawn_action.free()


func _test_prospect(menu: RadialActionMenu, handler: ActionHandler, road_vehicle: RoadVehicle3D) -> void:
	var old_player: PlayerAvatar = GlobalState.player
	var old_camera: Camera3D = GlobalState.active_cam
	var old_world: WorldMapScene = GlobalState.world_container
	var old_prospecting: ProspectingManager = Managers.prospecting
	var player_scene: PlayerAvatar = load("res://scenes/subscenes/player.tscn").instantiate()
	var body: BasicFpsPlayer = player_scene.walking_body
	body.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	add_child(player_scene)
	var terrain := Terrain3D.new()
	var world := WorldMapScene.new()
	world.map_key = "mpsb"
	world.terrain = terrain
	world.add_child(terrain)
	add_child(world)
	terrain.set_camera(GlobalState.active_cam)
	terrain.data.add_region_blankp(Vector3.ZERO)
	var prospecting := ProspectingManager.new()
	prospecting.marker_scene = load("res://scenes/subscenes/marker/survey_marker_3d.tscn")
	add_child(prospecting)
	prospecting.set_world(world)
	Managers.prospecting = prospecting
	body.global_position = Vector3(53, 6, 78)
	GlobalState.active_cam.position.x = 75.0
	var expected: Dictionary[String, float] = world.sample_minerals_at(body.global_position)
	var sample := Vector2(body.global_position.x, body.global_position.z)
	check(prospecting.get_traces_at_pos(sample) == expected and prospecting.readings_near(sample).is_empty(), "Fresh X/Z readings do not create surveys")
	check(prospecting.get_traces_at_pos(Vector2(4096, 4096)).is_empty(), "Geology queries outside terrain have no readings")
	check(expected != world.sample_minerals_at(GlobalState.active_cam.global_position), "Player and camera samples differ in the fixture")
	menu._on_radial_action_selected("Prospect", null)
	await get_tree().process_frame
	var dialog := UiState.current_diag as ProspectDialog
	check(dialog != null and dialog.can_prospect and dialog.readings.is_empty(), "Prospect opens an unsurveyed dialog")
	if dialog != null:
		var captured_position: Vector3 = body.global_position
		body.global_position += Vector3(30, 0, 0)
		dialog.find_child("ProspectButton", true, false).pressed.emit()
		check(dialog.readings == expected, "The Prospect button reads the player's captured position")
		var grid: GridContainer = dialog.get_node("%Content/Readings")
		check(grid.get_child_count() == 8, "Prospect displays a row for each of the four resources")
		check(body.process_mode == Node.PROCESS_MODE_DISABLED and not handler._on_action_triggered("Prospect"), "Prospect suspends walking and rejects duplicate dialogs")
		dialog.get_node("%OkButton").pressed.emit()
		await get_tree().process_frame
		check(UiState.current_diag == null and body.process_mode == Node.PROCESS_MODE_WHEN_PAUSED, "Closing Prospect restores the walking state")
		body.global_position = captured_position + Vector3.RIGHT
		await _test_survey_marker(handler, prospecting, expected)
	check(player_scene.control.enter_road_vehicle(road_vehicle), "Prospect fixture boards a road vehicle")
	check(handler._on_action_triggered("Prospect"), "Prospect dispatches from the vehicle menu")
	dialog = UiState.current_diag as ProspectDialog
	check(dialog != null and dialog.readings.is_empty() and dialog.message.begins_with("Step out"), "In-vehicle Prospect prompts the player to step out")
	if dialog != null:
		dialog.close_all()
		await get_tree().process_frame
	player_scene.control.exit_vehicle()
	body.global_position = Vector3(4096, 6, 4096)
	check(handler._on_action_triggered("Prospect"), "Prospect opens outside the terrain")
	dialog = UiState.current_diag as ProspectDialog
	check(dialog != null and dialog.readings.is_empty() and not dialog.message.is_empty(), "Missing terrain has a message instead of readings")
	if dialog != null:
		dialog.close_all()
		await get_tree().process_frame
	var old_construction: ConstructionManager = Managers.construction
	var construction := ConstructionManager.new()
	add_child(construction)
	Managers.construction = construction
	await _test_construction_footprint(construction, world)
	await _test_build(handler, body)
	Managers.construction = old_construction
	construction.free()
	var marker := prospecting.get_marker(1)
	prospecting.set_world(null)
	await get_tree().process_frame
	check(prospecting.get_marker(1) == null and not is_instance_valid(marker), "Clearing the active world removes its signs and readings")
	Managers.prospecting = old_prospecting
	prospecting.free()
	player_scene.free()
	world.free()
	GlobalState.player = old_player
	GlobalState.active_cam = old_camera
	GlobalState.world_container = old_world

func _test_construction_footprint(construction: ConstructionManager, world: WorldMapScene) -> void:
	var building := Node3D.new()
	var component := Constructable3D.new()
	building.add_child(component)
	var proposed := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(180, 0, 180))
	check(construction.site_error(world, building, proposed).contains("missing its placement shape"), "Construction reports a missing footprint")

	var mount := Node3D.new()
	mount.position = Vector3(0, 2, 3)
	building.add_child(mount)
	var body := StaticBody3D.new()
	body.position.x = 1.0
	mount.add_child(body)
	var footprint := CollisionShape3D.new()
	footprint.position.x = 2.0
	footprint.shape = BoxShape3D.new()
	body.add_child(footprint)
	component.placement_shape = footprint

	var obstacle := StaticBody3D.new()
	var obstacle_shape := CollisionShape3D.new()
	obstacle_shape.shape = BoxShape3D.new()
	obstacle.add_child(obstacle_shape)
	add_child(obstacle)
	obstacle.global_position = proposed * Vector3(3, 2, 3)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(construction.site_error(world, building, proposed).contains("overlap"), "Construction composes a nested footprint with the proposed rotation")
	obstacle.add_to_group(ConstructionManager.NON_BLOCKING_GROUP)
	check(construction.site_error(world, building, proposed).is_empty(), "Construction allows overlap with non-blocking markers")
	obstacle.free()
	building.free()

func _test_survey_marker(handler: ActionHandler, prospecting: ProspectingManager, expected: Dictionary[String, float]) -> void:
	var marker := prospecting.get_marker(1)
	check(marker != null and marker.readings == expected, "Prospecting places one survey sign with the reading")
	if marker == null:
		return
	var signpost := marker.get_node("Signpost") as MeshInstance3D
	check(signpost != null and signpost.mesh != null and signpost.scene_file_path.ends_with("/prospecting/prospect_marker.tscn"), "Survey sign uses the dedicated prospecting model")
	var reference: ClickRef = marker.get_click_ref()
	check(reference.entity_type == Enums.EntityTypes.MARKER and reference.entity_num == marker.marker_num, "Survey sign has a numbered MARKER click reference")
	check(handler._on_action_triggered("Prospect"), "Prospect reopens a surveyed spot")
	var dialog := UiState.current_diag as ProspectDialog
	check(dialog != null and dialog.readings == expected, "Nearby prospecting shows the saved results immediately")
	if dialog != null:
		dialog.find_child("ProspectButton", true, false).pressed.emit()
		dialog.close_all()
		await get_tree().process_frame
	check(prospecting.get_marker(1) == marker and prospecting.get_marker(2) == null, "Prospecting nearby reuses the sign")

	var picker := WorldPicker.new()
	add_child(picker)
	var interaction := WorldInteraction.new()
	interaction.entity_click_handler = BaseEntityClickHandler.new()
	interaction.add_child(interaction.entity_click_handler)
	add_child(interaction)
	interaction.pick_requested.connect(picker.pick)
	picker.picked.connect(interaction._on_world_picked)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var board: Vector3 = signpost.to_global(Vector3(0.0, 0.85, 0.067)) if signpost != null else marker.global_position
	camera.look_at_from_position(board + Vector3.BACK * 8.0, board)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = get_viewport().get_visible_rect().size * 0.5
	var press := release.duplicate() as InputEventMouseButton
	press.pressed = true
	var hud: Control = load("res://scenes/ui/ingame/ingame_overlay.tscn").instantiate()
	add_child(hud)
	var button := Button.new()
	button.position = release.position - Vector2(12, 12)
	button.size = Vector2(24, 24)
	hud.add_child(button)
	await get_tree().process_frame
	get_viewport().push_input(press, true)
	get_viewport().push_input(release, true)
	check(UiState.current_diag == null, "A HUD button gets first chance at the click")
	button.free()

	UiState.block_world_input(handler)
	get_viewport().push_input(press, true)
	get_viewport().push_input(release, true)
	check(UiState.current_diag == null, "A world input block prevents picking the sign")
	UiState.release_world_input(handler)
	get_viewport().push_input(press, true)
	get_viewport().push_input(release, true)
	dialog = UiState.current_diag as ProspectDialog
	check(dialog != null and dialog.readings == expected and not dialog.can_prospect, "A click through the HUD crosshair opens the sign from the current viewport camera")
	if dialog != null:
		dialog.close_all()
		await get_tree().process_frame
	var terrain_hits: Array[Vector3] = []
	interaction.terrain_clicked.connect(func(position: Vector3): terrain_hits.append(position))
	var terrain := GlobalState.world_container.terrain
	var ground := Vector3(board.x + 10.0, 0, board.z)
	camera.look_at_from_position(ground + Vector3.UP * 30, ground, Vector3.FORWARD)
	terrain.set_camera(camera)
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_viewport().push_input(press, true)
	get_viewport().push_input(release, true)
	check(terrain_hits.size() == 1 and terrain_hits[0].distance_to(ground) < 1.0, "A terrain click emits one world position")
	terrain.set_camera(GlobalState.active_cam)
	GlobalState.active_cam.make_current()
	camera.free()
	hud.free()
	interaction.free()
	picker.free()

func _test_build(handler: ActionHandler, body: BasicFpsPlayer) -> void:
	for view: GameEntity3D in [Industry3D.new(), RailStation3D.new(), BusStop3D.new()]:
		check(view._get_configuration_warnings().size() == 1, "Industry and station views warn about a missing Constructable3D")
		view.add_child(Constructable3D.new())
		check(view._get_configuration_warnings().is_empty(), "A direct Constructable3D clears the missing-component warning")
		view.free()

	check(handler._on_action_triggered("Build"), "Build opens the picker on a loaded map")
	var picker: GameDialog = UiState.current_diag
	if picker == null:
		return
	var tabs: CategoryTabs = picker.get_node("%Content/Categories")
	var options: VBoxContainer = picker.get_node("%Content/Options")
	check(tabs.get_children().map(func(tab: Button) -> String: return tab.tooltip_text) == ["Industry", "Station", "Misc"], "Build shows the requested tabs")
	tabs.get_child(1).pressed.emit()
	check(options.get_node("Station").visible and options.get_node("Empty").visible, "Station tab shows an empty state")
	tabs.get_child(2).pressed.emit()
	check(options.get_node("Misc").visible and options.get_node("Empty").visible, "Misc tab shows an empty state")
	tabs.get_child(0).pressed.emit()
	var mine := options.get_node("Industry/Mine") as Button
	check(mine != null and mine.text.contains("10000"), "Mine reads its construction cost from the scene")
	if mine == null:
		picker.close_all()
		await get_tree().process_frame
		return
	mine.pressed.emit()
	for frame: int in 3:
		await get_tree().process_frame
	var preview := UiState.current_diag as BuildPreview
	check(preview != null and body.process_mode == Node.PROCESS_MODE_DISABLED, "Selecting Mine starts an input-owning preview")
	if preview == null:
		return
	check(preview.model.scale.is_equal_approx(Vector3.ONE * 1.5), "Preview uses the mine model's authored scale")
	var meshes: Array[Node] = preview.model.find_children("*", "MeshInstance3D", true, false)
	check(not meshes.is_empty() and meshes[0].material_override is StandardMaterial3D and meshes[0].material_override.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "Mine preview uses an opaque override")
	var camera: Camera3D = GlobalState.active_cam
	camera.look_at_from_position(Vector3(115, 45, 115), Vector3(115, 0, 115), Vector3.FORWARD)
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	preview._update_preview(center)
	check(preview.model.is_visible_in_tree() and preview.model.global_position.distance_to(Vector3(115, 0, 115)) < 1.0, "Preview follows a ground hit")
	var first: Vector3 = preview.model.global_position
	preview._update_preview(center + Vector2(center.x * 0.4, 0))
	check(preview.model.is_visible_in_tree() and first.distance_to(preview.model.global_position) > 1.0, "Moving the cursor changes the ground position")
	camera.look_at(Vector3(115, 100, 114))
	preview._update_preview(center)
	check(not preview.model.is_visible_in_tree(), "Preview hides when the mouse points above terrain")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	preview._input(escape)
	await get_tree().process_frame
	check(UiState.current_diag == null and body.process_mode == Node.PROCESS_MODE_WHEN_PAUSED, "Escape removes the preview and restores walking")
	await _test_mine_construction(handler, camera, center)


func _test_mine_construction(handler: ActionHandler, camera: Camera3D, center: Vector2) -> void:
	check(GameTypes.ensure_initialized() == OK, "Mining uses the standard industry and goods catalogs")
	var world: WorldMapScene = GlobalState.world_container
	var site: Vector3 = _rich_coal_site(world)
	check(site.is_finite(), "The test terrain has a rich coal site")
	if not site.is_finite():
		return

	var old_industries: IndustrySpawner = Managers.industries
	var old_interchanges: InterchangesLoader = Managers.interchanges
	var spawner := IndustrySpawner.new()
	var interchanges := InterchangesLoader.new()
	add_child(spawner)
	add_child(interchanges)
	Managers.industries = spawner
	Managers.interchanges = interchanges
	check(interchanges.load_definitions([{"num": 0, "name": "Mine stop", "townNum": 0, "stops": []}]) == OK, "Mine stop fixture loads")
	var stop := RoadStationData.new(1, "Mine stop", 0)
	stop.position = site + Vector3.RIGHT * 30.0
	check(interchanges.register_stop(stop, 0) == OK, "The road stop belongs to an interchange")
	var bus: BusStop3D = load("res://scenes/subscenes/infr/station/bus_stop_3d.tscn").instantiate()
	bus.station = stop
	add_child(bus)

	var preview: BuildPreview = await _open_mine_preview(handler)
	if preview != null:
		await _confirm_coal_mine(preview, world, camera, center, site, spawner, bus)
	else:
		check(false, "Build opens a preview for construction")
	if not spawner.storage.get_containers().is_empty():
		await _test_occupied_mine_site(handler, camera, center, spawner.storage.get_containers()[0].global_position)

	spawner.free()
	check(stop.interchange.connections.industries.is_empty(), "Removing a runtime mine releases its interchange connection")
	bus.free()
	interchanges.free()
	Managers.industries = old_industries
	Managers.interchanges = old_interchanges


func _confirm_coal_mine(preview: BuildPreview, world: WorldMapScene, camera: Camera3D, center: Vector2,
		site: Vector3, spawner: IndustrySpawner, bus: BusStop3D) -> void:
	# The earlier survey fixture sits here. Move to it before testing a blind build.
	var surveyed := Vector3(53, 0, 78)
	camera.look_at_from_position(surveyed + Vector3.UP * 45.0, surveyed, Vector3.FORWARD)
	preview._update_preview(center)
	check(preview._site_detail.text.begins_with("Survey"), "Mine preview shows saved survey readings")
	camera.look_at_from_position(site + Vector3.UP * 45.0, site, Vector3.FORWARD)
	preview._update_preview(center)
	check(preview._site_detail.text == "Unsurveyed", "A blind site can still be selected")
	var selected_position: Vector3 = preview.model.global_position
	var enter := InputEventAction.new()
	enter.action = "ui_enter"
	enter.pressed = true
	preview._input(enter)
	for frame: int in 3:
		await get_tree().process_frame
	var dialog := UiState.current_diag as MineResourceDialog
	check(dialog != null and spawner.storage.get_all().is_empty(), "Enter opens resource selection before placing anything")
	if dialog == null:
		if is_instance_valid(preview):
			preview.close_all()
			await get_tree().process_frame
		return
	var readings: Dictionary[String, float] = world.sample_minerals_at(selected_position)
	check(dialog.readings == readings, "Confirmation samples the exact selected site")
	var choices: OptionButton = dialog.get_node("%ResourceChoices")
	var coal: int = -1
	for index: int in choices.item_count:
		if choices.get_item_text(index).begins_with("Coal"):
			coal = index
			break
	check(coal >= 0, "The mine offers coal")
	if coal < 0:
		dialog.close_all()
		await get_tree().process_frame
		return
	choices.select(coal)
	dialog.get_node("%BuildButton").pressed.emit()
	await get_tree().process_frame
	check(UiState.current_diag == null and spawner.storage.get_containers().size() == 1, "Confirming one resource creates a single industry")
	if spawner.storage.get_containers().is_empty():
		return
	var mine: Industry3D = spawner.storage.get_containers()[0]
	check(mine.global_position.is_equal_approx(selected_position), "The live mine occupies the selected site")
	check(mine.industry.ind_type.produces.size() == 1 and GameTypes.get_ind_type("COAL_MINE").produces[0].res_modifier == 4.0, "The site recipe has one output and preserves the authored coal mine recipe")
	var production: IndustryProduction = mine.get_node("Production")
	check(production.run_cycle() == IndustryProduction.BatchResult.COMPLETED, "The placed mine runs the standard production batch")
	var road_access: InventoryEndpoint = InventoryEndpoint.from_node(bus)
	var amount: float = road_access.inventory().get_amount("coal")
	check(is_equal_approx(amount, readings["coal"] * MinePlacement.FULL_RICHNESS_BATCH), "The nearby road stop receives coal scaled by local richness")
	var truck := Node3D.new()
	truck.add_child(InventoryContainer.new())
	add_child(truck)
	truck.global_position = bus.global_position
	var cargo: InventoryEndpoint = InventoryEndpoint.from_node(truck)
	check(InventoryTransferService.transfer(road_access, cargo, InventoryStack.new(&"coal", amount), amount).is_empty(), "A vehicle inventory can load the mine's coal from the road stop")
	truck.free()


func _open_mine_preview(handler: ActionHandler) -> BuildPreview:
	if not handler._on_action_triggered("Build"):
		return null
	UiState.current_diag.get_node("%Content/Options/Industry/Mine").pressed.emit()
	for frame: int in 3:
		await get_tree().process_frame
	return UiState.current_diag as BuildPreview


func _test_occupied_mine_site(handler: ActionHandler, camera: Camera3D, center: Vector2, site: Vector3) -> void:
	var preview: BuildPreview = await _open_mine_preview(handler)
	check(preview != null, "Another mine placement can start after confirmation")
	if preview == null:
		return
	await get_tree().physics_frame
	camera.look_at_from_position(site + Vector3.UP * 45.0, site, Vector3.FORWARD)
	preview._update_preview(center)
	var enter := InputEventAction.new()
	enter.action = "ui_enter"
	enter.pressed = true
	preview._input(enter)
	check(UiState.current_diag == preview and preview._site_detail.text.contains("overlap"), "A mine footprint cannot overlap an existing mine")
	preview.close_all()
	await get_tree().process_frame


func _rich_coal_site(world: WorldMapScene) -> Vector3:
	for x: int in range(32, 224, 8):
		for z: int in range(32, 224, 8):
			var site := Vector3(x, 0, z)
			if world.sample_minerals_at(site)["coal"] > 0.4:
				return site
	return Vector3.INF
