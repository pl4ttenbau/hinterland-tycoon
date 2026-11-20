## Placement tools offered in the build picker: whether each one can be used
## from the player's current spot, its caption, and starting it.
class_name BuildTools extends RefCounted

static func available(tool: Enums.BuildToolChoice) -> bool:
	var player := GlobalState.player
	if is_instance_valid(player) and player.control.is_in_vehicle():
		return false
	match tool:
		Enums.BuildToolChoice.ROAD_MARKER:
			return is_instance_valid(Managers.roads)
		Enums.BuildToolChoice.CONNECT_TRACKS, Enums.BuildToolChoice.RAIL_SIGNAL:
			return is_instance_valid(Managers.rails)
		Enums.BuildToolChoice.CREATE_STOP:
			var creator := _station_creator()
			return is_instance_valid(creator) and creator.is_available()
	return false

## A caption that depends on where the player stands, or "" to keep the scene's text.
static func title(tool: Enums.BuildToolChoice) -> String:
	if tool == Enums.BuildToolChoice.CREATE_STOP:
		var creator := _station_creator()
		if is_instance_valid(creator):
			var player := GlobalState.player
			return creator.action_title(player.walking_body if is_instance_valid(player) else null)
	return ""

## Opens the tool. Rechecks availability, since the player may have moved or
## boarded a vehicle since the picker was built.
static func start(tool: Enums.BuildToolChoice) -> bool:
	if UiState.current_diag != null or UiState.movement_blocked or not available(tool):
		return false
	match tool:
		Enums.BuildToolChoice.CREATE_STOP:
			return _station_creator().open_placement_dialog()
		Enums.BuildToolChoice.ROAD_MARKER:
			var marker_tool := _road_marker_tool()
			return is_instance_valid(marker_tool) and marker_tool.open_placement_dialog()
		Enums.BuildToolChoice.RAIL_SIGNAL:
			var signal_tool := _rail_signal_tool()
			return is_instance_valid(signal_tool) and signal_tool.open_placement_dialog()
		Enums.BuildToolChoice.CONNECT_TRACKS:
			return ConnectTracksTool.start()
	return false

static func _station_creator() -> StationCreator:
	if not is_instance_valid(Managers.interchanges):
		return null
	return Managers.interchanges.get_node_or_null("StationCreator") as StationCreator

static func _road_marker_tool() -> RoadMarkerTool:
	if not is_instance_valid(Managers.roads):
		return null
	for child: Node in Managers.roads.get_children():
		if child is RoadMarkerTool:
			return child
	return null

static func _rail_signal_tool() -> RailSignalTool:
	if not is_instance_valid(Managers.rails):
		return null
	return Managers.rails.get_node_or_null("RailSignalTool") as RailSignalTool
