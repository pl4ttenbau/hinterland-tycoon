@warning_ignore("missing_tool")
class_name RadialActionMenu extends Control

const ICONS := "res://assets/ui/icons/actions/"
var _previous_mouse_mode: Input.MouseMode
var _previous_movement_blocked: bool
var _walking_player: BasicFpsPlayer
var _walking_process_mode: Node.ProcessMode
var _owns_input := false

func _ready() -> void:
	%RadialMenu.set_items(available_actions())
	%RadialMenu.item_selected.connect(_on_radial_action_selected)
	%RadialMenu.item_hovered.connect(_on_radial_action_hovered)
	%RadialMenu.menu_closed.connect(_on_menu_closed)

## Rebuild on opening: vehicle context may have changed since the previous menu.
func available_actions() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var vehicles: VehiclePlacer = Managers.vehicles
	var in_road_vehicle := is_instance_valid(vehicles) and is_instance_valid(vehicles.player_road_vehicle)
	var in_train := is_instance_valid(GlobalState.player) and is_instance_valid(GlobalState.player.in_train)
	if in_road_vehicle or in_train:
		items.append(_item("Leave vehicle", "Enter", "exit_vehicle"))
	elif not GlobalState.trains.filter(is_instance_valid).is_empty():
		items.append(_item("Enter train", "Enter", "enter_vehicle"))
	if in_road_vehicle:
		items.append(_item("Auto-routing", "AutoRoute", "auto_route"))
	elif not in_train and is_instance_valid(Managers.roads):
		items.append(_item("Place road marker", "RoadMarker", "road_marker"))
	if not in_road_vehicle and not in_train and is_instance_valid(Managers.rails):
		items.append(_item("Connect tracks", "Connect", "connect_tracks"))
	items.append(_item("Inventory", "LoadUnload", "inventory"))
	items.append(_item("Company information", "Company", "company_info"))
	items.append(_item("Game menu", "Game Menu", "game_menu"))
	return items

func _item(title: String, id: String, icon: String) -> Dictionary:
	return {"title": title, "id": id, "texture": load(ICONS + icon + ".svg")}

func _menu_center() -> Vector2:
	# The child controls use local coordinates; the gameplay overlay can be offset.
	return get_global_transform_with_canvas().affine_inverse() * (get_viewport_rect().size / 2.0)

func show_label(action_text: String) -> void:
	%HoveredActionOuter.show()
	%HoveredActionLabel.text = action_text
	var hint: PanelContainer = %HoveredActionOuter
	hint.reset_size()
	hint.position = _menu_center() + Vector2(-hint.get_combined_minimum_size().x / 2.0, -205.0)

func hide_label() -> void:
	%HoveredActionLabel.text = ""
	%HoveredActionOuter.hide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if %RadialMenu.visible or UiState.in_main_menu or UiState.current_diag != null or UiState.movement_blocked:
			return
		%RadialMenu.set_items(available_actions())
		_previous_mouse_mode = Input.mouse_mode
		_previous_movement_blocked = UiState.movement_blocked
		_walking_player = GlobalState.player.player_parent if is_instance_valid(GlobalState.player) else null
		if is_instance_valid(_walking_player):
			_walking_process_mode = _walking_player.process_mode
			_walking_player.process_mode = Node.PROCESS_MODE_DISABLED
		_owns_input = true
		UiState.movement_blocked = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		%RadialMenu.open_menu(_menu_center())
		get_viewport().set_input_as_handled()
	# The owned control handles release/accept/cancel, so release cannot hide it
	# before its selection signal is emitted.

func _on_menu_closed(_menu: Control) -> void:
	_restore_input()
	hide_label()

func _restore_input() -> void:
	if not _owns_input:
		return
	_owns_input = false
	UiState.movement_blocked = _previous_movement_blocked
	Input.mouse_mode = _previous_mouse_mode
	if is_instance_valid(_walking_player):
		_walking_player.process_mode = _walking_process_mode

func _on_radial_action_selected(key: Variant, _position: Variant) -> void:
	_restore_input()
	hide_label()
	# Dispatch after input has unwound; dialogs capture the restored input state.
	SignalBus.action_menu_triggered.emit.call_deferred(str(key))

func _on_radial_action_hovered(item: Dictionary) -> void:
	if item.is_empty():
		hide_label()
	else:
		show_label(item.title)

func _exit_tree() -> void:
	_restore_input()
