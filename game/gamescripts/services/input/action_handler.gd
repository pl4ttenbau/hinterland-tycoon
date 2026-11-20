## Resolves an action ID against the live session when the circular menu dispatches it.
@icon("res://assets/icons/icon_input_white.png")
class_name ActionHandler extends Node

const ROUTE_DIALOG = preload("res://game/gamescripts/ui/dialogs/road_route/road_route_dialog.gd")
const BUILD_PICKER = preload("res://scenes/ui/dialogs/build/build_picker_dialog.tscn")


func _on_action_triggered(action_name: String) -> bool:
	if action_name.is_empty() or UiState.current_diag != null or UiState.movement_blocked:
		return false
	# Availability can change while the menu is open. Feature entry points validate again.
	match action_name:
		"Game Menu":
			return _open_dialog("res://scenes/ui/dialogs/game_menu/game_menu_dialog.tscn")
		"Company":
			return _open_dialog("res://scenes/ui/dialogs/company_info/company_info_dialog.tscn")
		"AutoRoute":
			return _open_road_route_dialog()
		"Coupling":
			return _open_coupling_dialog()
		"Prospect":
			return Prospecting.open_at_player()
		"Build":
			return _open_build_picker()
		"RemoveRailSignal":
			return _remove_rail_signal()

	# Enter, Spawn and Inventory use the BaseAction children in GameSession.
	for child: Node in get_children():
		if child is BaseAction and child.key == action_name:
			child.on_trigger()
			return true
	return false


func _open_dialog(scene_path: String) -> bool:
	var scene := load(scene_path) as PackedScene
	get_tree().root.add_child(scene.instantiate())
	return true


## Build is the one placement action: the picker lists industries and placement
## tools, and whatever is chosen starts once the picker has left the tree and released world input.
func _open_build_picker() -> bool:
	var picker := BUILD_PICKER.instantiate() as GameDialog
	picker.closed.connect(_on_build_picker_closed.bind(picker), CONNECT_ONE_SHOT)
	get_tree().root.add_child(picker)
	return true


func _on_build_picker_closed(result: Variant, picker: GameDialog) -> void:
	if result is BuildChoice:
		picker.tree_exited.connect(_start_build_choice.bind(result), CONNECT_ONE_SHOT | CONNECT_DEFERRED)


func _start_build_choice(choice: BuildChoice) -> void:
	if choice.is_tool():
		BuildTools.start(choice.tool)
	else:
		MinePlacement.start(GlobalState.world_container, choice)


func _open_road_route_dialog() -> bool:
	var player := GlobalState.player
	if not is_instance_valid(player):
		return false
	var vehicle := player.control.current_road_vehicle()
	if not is_instance_valid(vehicle):
		return false
	get_tree().root.add_child(ROUTE_DIALOG.create(vehicle))
	return true


func _open_coupling_dialog() -> bool:
	var player := GlobalState.player
	if not is_instance_valid(player):
		return false
	var train := player.control.current_train()
	if not TrainCoupling.available(train):
		return false
	get_tree().root.add_child(TrainCouplingDialog.create(train.locomotive))
	return true


func _remove_rail_signal() -> bool:
	if not is_instance_valid(Managers.rails):
		return false
	var tool := Managers.rails.get_node_or_null("RailSignalTool") as RailSignalTool
	return is_instance_valid(tool) and tool.remove_near_player()
