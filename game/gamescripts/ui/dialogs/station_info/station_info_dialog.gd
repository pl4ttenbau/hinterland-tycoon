class_name StationInfoDialog extends ModalGameDialog

var stop: AbstractStation
var _inventory: GoodsInventory

func _ready() -> void:
	dialog_key = "StationInfoDialog"
	_suspend_world_input()
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

	_fill_connections()
	_refresh_inventory()

## Show the interchange's physical access points and the buildings it serves.
func _fill_connections() -> void:
	var list: ItemList = %Connections
	list.clear()
	var interchange: InterchangeData = stop.interchange
	var stops: Array[AbstractStation] = [stop]
	if interchange != null:
		stops = interchange.stops
	for connection: AbstractStation in stops:
		list.add_item(_describe_stop(connection), null, false)

	var buildings: StationConnections = interchange.connections if interchange != null else stop.connections
	for connection: StationIndustryConnection in buildings.industries:
		var industry: IndustryData = connection.industry
		if industry != null and industry.ind_type != null:
			var industry_name: String = industry.ind_name if not industry.ind_name.is_empty() else industry.ind_type.name
			list.add_item("Industry · %s" % industry_name, null, false)
	if not buildings.houses.is_empty():
		list.add_item("Connected homes · %d" % buildings.houses.size(), null, false)

func _describe_stop(connection: AbstractStation) -> String:
	if connection is RailStationData:
		return "Rail stop #%d · Track #%d" % [connection.num, connection.track_num]
	if connection is RoadStationData:
		return "Road stop #%d · Road #%d" % [connection.num, connection.road_num]
	return "Stop #%d" % connection.num

## Passenger batches show the city and station of their destination interchange.
func _refresh_inventory() -> void:
	var list: ItemList = %Inventory
	list.clear()
	if _inventory == null:
		%Capacity.text = "Inventory unavailable"
		return
	%Capacity.text = "%s / %s units" % [
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
