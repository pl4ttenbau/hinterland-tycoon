## Chooses the gameplay actions shown by the reusable radial control.
@warning_ignore("missing_tool")
class_name RadialActionMenu extends Control

signal action_requested(action_name: String)

const ICONS := "res://assets/ui/icons/actions/"

@onready var _menu: HinterlandRadialMenu = %RadialMenu


func _ready() -> void:
	_menu.set_items(available_actions())
	_menu.item_selected.connect(_on_radial_action_selected)
	_menu.item_hovered.connect(_on_radial_action_hovered)
	_menu.menu_closed.connect(_on_menu_closed)

## Rebuild on opening: vehicle context may have changed since the previous menu.
func available_actions() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var player := GlobalState.player
	var in_vehicle := is_instance_valid(player) and player.control.is_in_vehicle()
	var in_road_vehicle := in_vehicle and is_instance_valid(player.control.current_road_vehicle())
	if in_vehicle:
		items.append(_item("Leave vehicle", "Enter", "exit_vehicle"))
	elif not GlobalState.trains.filter(is_instance_valid).is_empty():
		items.append(_item("Enter train", "Enter", "enter_vehicle"))
	if in_road_vehicle:
		items.append(_item("Auto-routing", "AutoRoute", "auto_route"))
	elif not in_vehicle and is_instance_valid(Managers.roads):
		items.append(_item("Place road marker", "RoadMarker", "road_marker"))
	if not in_vehicle and is_instance_valid(Managers.rails):
		items.append(_item("Connect tracks", "Connect", "connect_tracks"))
	if not in_vehicle and is_instance_valid(Managers.interchanges):
		var creator: StationCreator = Managers.interchanges.get_node_or_null("StationCreator")
		if is_instance_valid(creator) and creator.is_available():
			items.append(_item("Create stop", "CreateStop", "create_stop"))
	items.append(_item("Prospect", "Prospect", "prospect"))
	items.append(_item("Build", "Build", "build"))
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
	# The control handles release, selection and cancel once the menu is open.
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
		return
	if _menu.visible or UiState.is_world_input_blocked():
		return
	_menu.set_items(available_actions())
	UiState.block_world_input(self)
	_menu.open_menu(_menu_center())
	get_viewport().set_input_as_handled()

func _on_menu_closed(_menu: Control) -> void:
	UiState.release_world_input(self)
	hide_label()

func _on_radial_action_selected(key: Variant, _position: Variant) -> void:
	UiState.release_world_input(self)
	hide_label()
	# Dispatch after input has unwound; dialogs capture the restored input state.
	action_requested.emit.call_deferred(str(key))

func _on_radial_action_hovered(item: Dictionary) -> void:
	if item.is_empty():
		hide_label()
	else:
		show_label(item.title)

func _exit_tree() -> void:
	UiState.release_world_input(self)
