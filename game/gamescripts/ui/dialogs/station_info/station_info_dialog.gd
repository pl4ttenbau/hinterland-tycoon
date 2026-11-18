class_name StationInfoDialog extends ModalGameDialog

const RAIL_ICON := preload("res://assets/icons/icon_rail_track_white.png")
const ROAD_ICON := preload("res://assets/icons/icon_road_white.png")
const HOUSE_ICON := preload("res://assets/icons/icon_house_white.png")
const INDUSTRY_ICON := preload("res://assets/icons/icon_industry_white.png")

var stop: AbstractStation
var _inventory: GoodsInventory

func _ready() -> void:
	dialog_key = "StationInfoDialog"
	if stop == null:
		close_all()
		return

	title_text = stop.station_name if not stop.station_name.is_empty() else "Station"
	var city: String = stop.town_name.strip_edges()
	%TownName.text = city
	%TownName.visible = not city.is_empty()
	if city.is_empty():
		%StationNameInset.add_theme_constant_override("margin_left", 0)
	%CloseButton.pressed.connect(close_all)
	%CloseButton.grab_focus()

	_inventory = stop.get_interchange_inventory()
	if _inventory == null:
		var view: InventoryEntity3D = stop.get_inventory_view()
		if is_instance_valid(view):
			_inventory = view.get_inventory()
	if _inventory != null:
		_inventory.goods_change.connect(_refresh_inventory)

	_fill_stops()
	_fill_coverage()
	_refresh_inventory()

func _fill_stops() -> void:
	var interchange: InterchangeData = stop.interchange
	_add_stop_row(stop, true)
	if interchange != null:
		for other: AbstractStation in interchange.stops:
			if other != stop:
				_add_stop_row(other, false)

func _add_stop_row(connection: AbstractStation, opened_here: bool) -> void:
	var list: ItemList = %Stops
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
		elif connection.curve_offset >= 0.0:
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
	var row: int = list.add_item(caption, icon, false)
	var reference: String = "Stop #%d" % connection.num
	if not line_id.is_empty():
		reference += " · " + line_id
	list.set_item_tooltip(row, "%s\n%s" % [caption, reference])
	if opened_here:
		list.set_item_custom_fg_color(row, list.get_theme_color("caret_color"))

func _line_label(line: AbstractTrack, fallback: String) -> String:
	if line != null and not line.track_name.strip_edges().is_empty():
		return line.track_name
	return fallback

func _fill_coverage() -> void:
	var list: ItemList = %CoverageList
	var interchange: InterchangeData = stop.interchange
	var buildings: StationConnections = interchange.connections if interchange != null else stop.connections
	var homes: int = buildings.houses.size()
	list.add_item("Connected homes · %d" % homes, HOUSE_ICON, false)
	var industries: int = 0
	for connection: StationIndustryConnection in buildings.industries:
		var industry: IndustryData = connection.industry
		if industry != null and industry.ind_type != null:
			var industry_name: String = industry.ind_name if not industry.ind_name.is_empty() else industry.ind_type.name
			list.add_item(industry_name, INDUSTRY_ICON, false)
			industries += 1
	if industries == 0:
		list.add_item("No connected industries", INDUSTRY_ICON, false)

## Passenger batches show the city and station of their destination interchange.
func _refresh_inventory() -> void:
	var list: ItemList = %InventoryList
	list.clear()
	if _inventory == null:
		%Capacity.text = "Inventory unavailable"
		return
	var caption: String = "Shared stock" if stop.interchange != null else "Stop stock"
	%Capacity.text = "%s · %s / %s units" % [
		caption,
		InventoryPresentation.quantity(_inventory.storage.current_storage),
		InventoryPresentation.quantity(_inventory.amount_max),
	]
	for passengers: bool in [false, true]:
		for stack: InventoryStack in _inventory.stacks(passengers):
			var label: String = "%s × %s" % [InventoryPresentation.quantity(stack.amount), String(stack.good_key).capitalize()]
			if passengers:
				label += " · %s" % InventoryPresentation.destination(stack.destination_interchange)
			list.add_item(label, InventoryPresentation.icon(stack.good_key), false)
	if list.item_count == 0:
		list.add_item("Empty", null, false)

func _exit_tree() -> void:
	if _inventory != null and _inventory.goods_change.is_connected(_refresh_inventory):
		_inventory.goods_change.disconnect(_refresh_inventory)
	super()
