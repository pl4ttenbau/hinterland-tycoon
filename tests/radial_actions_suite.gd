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
	var root: Window = get_tree().root
	var old_vehicles: VehiclePlacer = Managers.vehicles
	var old_roads: RoadsLoader = Managers.roads
	var old_rails: RailsLoader = Managers.rails
	var old_player: PlayerHead3D = GlobalState.player
	var old_trains: Array[Train3D] = GlobalState.trains
	var old_main_menu: bool = UiState.in_main_menu
	var old_blocked: bool = UiState.movement_blocked
	var vehicles := VehiclePlacer.new()
	var roads := RoadsLoader.new()
	var rails := RailsLoader.new()
	var player := PlayerHead3D.new()
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
	check("RoadMarker" in _ids(menu) and "AutoRoute" not in _ids(menu), "Walking offers marker, not auto-routing")
	check("Enter" not in _ids(menu), "No train entry when train list is empty")
	for unsupported: String in ["Place"]:
		check(unsupported not in _ids(menu), "Unimplemented action is not shown: " + unsupported)
	var road_vehicle := RoadVehicle3D.new()
	vehicles.player_road_vehicle = road_vehicle
	check("Company" in _ids(menu) and "Game Menu" in _ids(menu), "Both new menu dialogs remain available inside a vehicle")
	check("AutoRoute" in _ids(menu) and "Enter" in _ids(menu), "Occupied road vehicle offers routing and exit")
	check("RoadMarker" not in _ids(menu) and "Connect" not in _ids(menu), "Road vehicle hides on-foot actions")
	vehicles.player_road_vehicle = null
	var train := Train3D.new()
	player.in_train = train
	check("AutoRoute" not in _ids(menu) and "RoadMarker" not in _ids(menu), "Train occupancy does not expose road actions")
	var control: Control = menu.get_node("%RadialMenu")
	control.set_items(menu.available_actions())
	check(control.get_node("ItemIcons").get_child_count() == 4, "Changing context rebuilds icon nodes")
	check(is_equal_approx(control.item_angle * 4, control.circle_coverage * TAU), "Changing context recalculates segment geometry")
	player.in_train = null
	var handler := ActionHandler.new()
	var action := CountingAction.new()
	action.name = "ConnectAction"
	action.key = "Connect"
	handler.add_child(action)
	root.add_child(handler)
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
	menu._input(release)
	check(radial.visible, "Wrapper does not swallow selection on release")
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
	vehicles.player_road_vehicle = null
	Managers.vehicles = old_vehicles
	Managers.roads = old_roads
	Managers.rails = old_rails
	GlobalState.player = old_player
	GlobalState.trains = old_trains
	UiState.in_main_menu = old_main_menu
	UiState.movement_blocked = old_blocked
	player.free()
	road_vehicle.free()
	train.free()
	vehicles.free()
	roads.free()
	rails.free()
	print("Radial actions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
