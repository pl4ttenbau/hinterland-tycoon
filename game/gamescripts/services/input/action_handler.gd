## Resolves an action ID against the live session when the circular menu dispatches it.
@icon("res://assets/icons/icon_input_white.png")
class_name ActionHandler extends Node

const ROUTE_DIALOG = preload("res://game/gamescripts/ui/dialogs/road_route/road_route_dialog.gd")


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
		"Prospect":
			return Prospecting.open_at_player()
		"Build":
			return MinePlacement.open_picker(GlobalState.world_container)
		"CreateStop":
			return _open_station_creator()
		"RoadMarker":
			return _open_road_marker_tool()

	# Enter, Connect and Inventory use the BaseAction children in GameSession.
	for child: Node in get_children():
		if child is BaseAction and child.key == action_name:
			child.on_trigger()
			return true
	return false


func _open_dialog(scene_path: String) -> bool:
	var scene := load(scene_path) as PackedScene
	get_tree().root.add_child(scene.instantiate())
	return true


func _open_road_route_dialog() -> bool:
	var player := GlobalState.player
	if not is_instance_valid(player):
		return false
	var vehicle := player.control.current_road_vehicle()
	if not is_instance_valid(vehicle):
		return false
	get_tree().root.add_child(ROUTE_DIALOG.create(vehicle))
	return true


func _open_station_creator() -> bool:
	if not is_instance_valid(Managers.interchanges):
		return false
	var creator := Managers.interchanges.get_node_or_null("StationCreator") as StationCreator
	return is_instance_valid(creator) and creator.open_placement_dialog()


func _open_road_marker_tool() -> bool:
	if not is_instance_valid(Managers.roads):
		return false
	for child: Node in Managers.roads.get_children():
		if child is RoadMarkerTool:
			return child.open_placement_dialog()
	return false
