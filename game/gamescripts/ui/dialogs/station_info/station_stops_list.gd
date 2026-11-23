## Every physical stop of the interchange, the one that was clicked first.
class_name StationStopsList extends ItemList

const RAIL_ICON := preload("res://assets/icons/icon_rail_track_white.png")
const ROAD_ICON := preload("res://assets/icons/icon_road_white.png")

func show_stops(stop: AbstractStation) -> void:
	clear()
	_add_stop_row(stop, true)
	if stop.interchange != null:
		for other: AbstractStation in stop.interchange.stops:
			if other != stop:
				_add_stop_row(other, false)

func _add_stop_row(connection: AbstractStation, opened_here: bool) -> void:
	var parts := PackedStringArray()
	var icon: Texture2D
	var line_id: String
	if opened_here:
		parts.append("This stop")
	if connection is RailStationData:
		icon = RAIL_ICON
		line_id = "Track #%d" % connection.track_num
		var track: RailTrackData
		if is_instance_valid(Managers.rails):
			track = Managers.rails.track_storage._by_id.get(connection.track_num)
		parts.append("Cargo rail" if connection.station_type == "STATION_GOODS" else "Passenger rail")
		if connection.hide_building:
			parts.append("Hidden platform")
		else:
			parts.append("Left side" if connection.platform_side == RailStationData.PlatformSide.LEFT else "Right side")
		parts.append(_line_label(track, line_id))
	elif connection is RoadStationData:
		icon = ROAD_ICON
		line_id = "Road #%d" % connection.road_num
		var road: RoadData
		if is_instance_valid(Managers.roads):
			road = Managers.roads.storage._by_id.get(connection.road_num)
		parts.append("Road stop")
		match connection.direction:
			Enums.RoadStopDirection.ROAD_NODES_INCREASE: parts.append("Toward road end")
			Enums.RoadStopDirection.ROAD_NODES_DECREASE: parts.append("Toward road start")
			Enums.RoadStopDirection.BOTH_DIRECTIONS: parts.append("Both directions")
		if connection.hide_building:
			parts.append("Hidden shelter")
		parts.append(_line_label(road, line_id))
	else:
		parts.append("Stop")
	var caption: String = " · ".join(parts)
	var row: int = add_item(caption, icon, false)
	var reference: String = "Stop #%d" % connection.num
	if not line_id.is_empty():
		reference += " · " + line_id
	set_item_tooltip(row, "%s\n%s" % [caption, reference])
	if opened_here:
		set_item_custom_fg_color(row, get_theme_color("caret_color"))

func _line_label(line: AbstractInfrLine, fallback: String) -> String:
	if line != null and not line.track_name.strip_edges().is_empty():
		return line.track_name
	return fallback
