@icon("res://assets/icons/icon_input_white.png")
class_name ActionHandler extends Node

func _enter_tree() -> void:
	SignalBus.action_menu_triggered.connect(Callable(self, "_on_action_triggered"))
	
func _on_action_triggered(action_name: String) -> bool:
	if action_name.is_empty() or UiState.current_diag != null:
		return false
	if action_name in ["Game Menu", "Company"]:
		var scene_path: String = "res://scenes/ui/dialogs/game_menu/game_menu_dialog.tscn" if action_name == "Game Menu" else "res://scenes/ui/dialogs/company_info/company_info_dialog.tscn"
		var dialog: PackedScene = load(scene_path)
		get_tree().root.add_child(dialog.instantiate())
		return true
	if action_name == "AutoRoute":
		return is_instance_valid(Managers.vehicles) and Managers.vehicles.open_road_route_dialog()
	if action_name == "CreateStop":
		if not is_instance_valid(Managers.interchanges):
			return false
		var creator: StationCreator = Managers.interchanges.get_node_or_null("StationCreator")
		return is_instance_valid(creator) and creator.open_placement_dialog()
	if action_name == "RoadMarker":
		if not is_instance_valid(Managers.roads):
			return false
		for child: Node in Managers.roads.get_children():
			if child is RoadMarkerTool:
				return child.open_placement_dialog()
		return false
	for child: Node in get_children():
		if child is BaseAction and child.key == action_name:
			child.on_trigger()
			return true
	return false
