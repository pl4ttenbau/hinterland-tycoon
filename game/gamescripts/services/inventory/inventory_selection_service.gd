## Discover nearby inventory components, independently of the transfer dialog and row widgets.
class_name InventorySelectionService extends RefCounted

var _items: Array[InventoryEndpoint] = []
var _seen: Dictionary = {}
var _origin: Vector3

func discover() -> Array[InventoryEndpoint]:
	_items.clear()
	_seen.clear()
	if not is_instance_valid(GlobalState.player):
		return _items
	var player := GlobalState.player
	var access := player.control.interaction_anchor()
	_origin = access.global_position
	# The occupied vehicle is the useful default; the player's own bag stays accessible.
	var road_vehicle := player.control.current_road_vehicle()
	if is_instance_valid(road_vehicle):
		_offer(road_vehicle, road_vehicle.inventory_component.display_name, access, InventoryEndpoint.Kind.VEHICLE)
	var occupied_train := player.control.current_train()
	if is_instance_valid(occupied_train):
		_offer(occupied_train, "Train %d" % occupied_train.num, access, InventoryEndpoint.Kind.VEHICLE)
	_offer(player, "Player", access, InventoryEndpoint.Kind.PLAYER)
	_offer_stops(player.current_station())
	if is_instance_valid(Managers.vehicles):
		for vehicle: RoadVehicle3D in Managers.vehicles.road_vehicles:
			if is_instance_valid(vehicle) and is_instance_valid(vehicle.inventory_component):
				_offer_nearby(vehicle, vehicle.inventory_component.display_name, null, InventoryEndpoint.Kind.VEHICLE)
		for train: Train3D in Managers.vehicles.trains:
			if is_instance_valid(train):
				_offer_nearby(train, "Train %d" % train.num, train.get_cam(), InventoryEndpoint.Kind.VEHICLE)
	for industry: Industry3D in GlobalState.ind_bld_containers:
		if is_instance_valid(industry):
			_offer_nearby(industry, str(industry.name), null, InventoryEndpoint.Kind.INDUSTRY)
	return _items

func _offer_stops(current: RailStation3D) -> void:
	if is_instance_valid(current):
		_offer(current, "%s (rail stop)" % current.station.get_display_name(), null, InventoryEndpoint.Kind.STOP)
	if is_instance_valid(Managers.interchanges):
		for stop: AbstractStation in Managers.interchanges.stops_by_num.values():
			var view: InventoryEntity3D = stop.get_inventory_view()
			if is_instance_valid(view) and view.global_position.distance_to(_origin) <= InventoryTransferService.REACH_METRES:
				_offer(view, "%s · stop %d" % [stop.get_display_name(), stop.num], null, InventoryEndpoint.Kind.STOP)

func _offer_nearby(owner: Node3D, label: String, access: Node3D = null, kind: InventoryEndpoint.Kind = InventoryEndpoint.Kind.OTHER) -> void:
	var anchor: Node3D = access if is_instance_valid(access) else owner
	if is_instance_valid(owner) and anchor.global_position.distance_to(_origin) <= InventoryTransferService.REACH_METRES:
		_offer(owner, label, anchor, kind)

func _offer(owner: Node3D, label: String, access: Node3D = null, kind: InventoryEndpoint.Kind = InventoryEndpoint.Kind.OTHER) -> void:
	var endpoint: InventoryEndpoint = InventoryEndpoint.from_node(owner, label, access)
	if endpoint == null or not endpoint.available():
		return
	endpoint.kind = kind
	var id: int = endpoint.inventory().get_instance_id()
	if _seen.has(id):
		# Several physical stops can expose the same stock. Use the closest one
		# for manual reach checks while keeping just one row for the inventory.
		var index: int = _seen[id]
		if endpoint.position().distance_squared_to(_origin) < _items[index].position().distance_squared_to(_origin):
			_items[index] = endpoint
		return
	_seen[id] = _items.size()
	_items.append(endpoint)
