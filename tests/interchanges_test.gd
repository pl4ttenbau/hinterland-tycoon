class_name InterchangesTest extends Node

const SERVICES = preload("res://scenes/subscenes/world_services.tscn")

var failures: int = 0
var phases: Array[String] = []
var coordinator: WorldServicesCoordinator

func _ready() -> void:
	self._run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		self.failures += 1
		push_error(message)

func _run() -> void:
	self.check(GameTypes.ensure_initialized() == OK, "Types initialize before world services")
	self.check(self.test_catalog_validation(), "Catalog validation completed")
	self.check(self.test_mixed_loading(), "Mixed interchange loading completed")
	self.check(self.test_migrated_maps(), "Migrated map validation completed")
	print("Interchange tests: %d failures" % self.failures)
	get_tree().quit(1 if self.failures > 0 else 0)

func definitions() -> Array:
	return [{"num": 7, "name": "Shared station", "townNum": 3, "townName": "Town", "stops": [
		{"num": 12, "domain": "RAIL", "trackNum": 4, "nodeIndex": 0, "hideBuilding": true},
		{"num": 13, "domain": "ROAD", "roadNum": 42, "nodeIndex": 0, "roadStopDirection": "BOTH_DIRECTIONS"}
	]}, {"num": 8, "name": "Empty interchange", "townNum": 3, "stops": []}]

func test_catalog_validation() -> bool:
	var loader := InterchangesLoader.new()
	var source: Array = self.definitions()
	self.check(loader.load_definitions(source) == OK, "Interchanges can be constructed without network data")
	var first: InterchangeData = loader.by_num[7]
	self.check(first.stops.is_empty() and loader.stops_by_num.is_empty(), "Parent creation does not create stops as a side effect")
	self.check(not source[0]["stops"][0].has("interchangeNum"), "Loader does not mutate authored definitions")
	print("Checking invalid interchange catalogs; the following validation errors are expected.")
	var duplicate_stop: Array = self.definitions()
	duplicate_stop[0]["stops"][1]["num"] = 12
	var duplicate_parent: Array = self.definitions()
	duplicate_parent[1]["num"] = 7
	var duplicate_anchor: Array = self.definitions()
	duplicate_anchor[0]["stops"].append({"num": 14, "domain": "RAIL", "trackNum": 4, "nodeIndex": 0})
	var invalid: Array = [null, {}, [null], duplicate_parent, duplicate_stop, duplicate_anchor]
	for fields: Dictionary in [
		{"num": -1}, {"domain": "WATER"}, {"nodeIndex": 0.5}, {"nodeIndex": false},
		{"trackNum": "4"}, {"hideBuilding": "true"}, {"type": 7},
		{"name": "Conflicting child name"}, {"interchangeNum": 999}
	]:
		var fixture: Array = self.definitions()
		fixture[0]["stops"][0].merge(fields, true)
		invalid.append(fixture)
	var invalid_direction: Array = self.definitions()
	invalid_direction[0]["stops"][1]["roadStopDirection"] = "road_nodes_increase"
	invalid.append(invalid_direction)
	var legacy: Array = self.definitions()
	var legacy_stop: Dictionary = legacy[0]["stops"][1]
	legacy_stop.erase("roadStopDirection")
	legacy_stop["roadSide"] = "BOTH"
	invalid.append(legacy)
	for fixture: Variant in invalid:
		self.check(loader.load_definitions(fixture) != OK, "Invalid catalog is rejected")
		self.check(loader.by_num[7] == first and loader.stop_definitions.size() == 2, "Invalid reload leaves the previous catalog intact")
	var path: String = "/tmp/interchange-invalid-%d.json" % OS.get_process_id()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	self.check(loader.load_interchanges("unused", path) != OK, "Malformed JSON is rejected")
	self.check(loader.load_interchanges("unused", path + ".missing") != OK, "Missing catalog is reported")
	DirAccess.remove_absolute(path)
	loader.free()
	return true

func _parents_loaded(parents: Array[InterchangeData]) -> void:
	self.phases.append("parents")
	self.check(parents.size() == 2 and coordinator.interchanges.stops_by_num.is_empty(), "All parents exist before either stop loader runs")
	self.check(not coordinator.stations.is_loaded and not coordinator.road_stops.is_loaded, "Both stop loaders wait for interchange creation")

func _stops_linked() -> void:
	self.phases.append("stops")
	var registry: Dictionary = coordinator.interchanges.stops_by_num
	self.check(registry.size() == 2 and registry[12] is RailStationData and registry[13] is RoadStationData, "Shared registry contains both stop types")
	self.check(registry[12].interchange == registry[13].interchange \
		and registry[12].interchange == coordinator.interchanges.by_num[7], "Both stops share the already-created parent Resource")

func write_fixture(folder: String, filename: String, data: Variant) -> bool:
	var file := FileAccess.open(folder.path_join(filename), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func test_mixed_loading() -> bool:
	var key: String = "__interchange_test_%d" % OS.get_process_id()
	var folder: String = "res://world/%s/jsondata" % key
	DirAccess.make_dir_recursive_absolute(folder)
	self.check(write_fixture(folder, "interchanges.json", self.definitions()), "Fixture catalog saved")
	self.check(write_fixture(folder, "tracks.json", [{"num": 4, "type": "750_MM", "points": [
		{"pos": [10, 2, 20]}, {"pos": [30, 2, 20]}
	]}]), "Fixture rail geometry saved")
	self.check(write_fixture(folder, "roads.json", [{"num": 42, "type": "rural_road", "points": [
		{"pos": [10, 2, 25]}, {"pos": [30, 2, 25]}
	]}]), "Fixture road geometry saved")
	self.check(write_fixture(folder, "vehicles_depots.json", {"depots": []}), "Fixture depot catalog saved")
	coordinator = SERVICES.instantiate()
	self.add_child(coordinator)
	self.check(coordinator.initialize() == OK, "Real service scene initializes")
	coordinator.interchanges.interchanges_loaded.connect(self._parents_loaded)
	coordinator.interchanges.stops_linked.connect(self._stops_linked)
	self.check(coordinator.load_map_data(key) == OK, "Explicit map data pipeline loads mixed stops")
	self.check(self.phases == ["parents", "stops"], "Parents and stops publish in dependency order")
	var interchange: InterchangeData = coordinator.interchanges.by_num[7]
	var rail: RailStationData = coordinator.stations.stations_by_num[12]
	var road: RoadStationData = coordinator.road_stops.by_num[13]
	self.check(interchange.stops.size() == 2 and rail.interchange_num == 7 and road.interchange_num == 7, "Nested membership is bidirectional")
	interchange.interchange_name = "Renamed interchange"
	self.check(rail.station_name == "Renamed interchange" and road.station_name == rail.station_name, "Name metadata comes from one shared parent")
	var track: RailTrackData = coordinator.rails.track_storage._by_id[4]
	var link: NodeStationLinkData = track.nodes[0].station
	self.check(link.num == 12 and link.parent_station == rail and link.parent_station_num == 12 \
		and coordinator.stations.node_stations_storage.get_by_num(12) == link, "Rail node adapter preserves the manual stop number")
	self.check(rail.track_num == 4 and rail.node_index == 0 and rail.position == Vector3(10, 2, 20), "Rail placement comes from explicit track/node JSON")
	self.check(rail.station_type == "STATION_PASS", "Rail stops without an explicit type retain the passenger default")
	self.check(road.station_type.is_empty(), "Road stop types remain unspecified until their vocabulary is defined")
	self.check(road.position == Vector3(10, 2, 25), "Road placement comes from explicit road/node JSON")
	var town := TownData.new()
	town.num = 3
	town.town_name = "Town"
	var towns: Array[TownData] = [town]
	coordinator.interchanges._on_map_towns_loaded(towns)
	self.check(town.stations.size() == 2 and rail.connected_town == town and road.connected_town == town, "Town binding accepts both stop domains")
	coordinator.stations._on_map_towns_loaded(towns)
	coordinator.road_stops._on_map_towns_loaded(towns)
	var rail_view: RailStation3D = coordinator.stations.get_station_3d_with_num(12)
	self.check(rail_view != null and rail_view.global_position.is_equal_approx(rail.position), "Authored rail inventory is located at the stop")
	self.check(link.station3d != null and link.station3d.global_position.is_equal_approx(rail.position), "Rail node zero spawns at its authored position")
	var rail_sign: StationSign3D = link.station3d.get_node("StationSign3D")
	self.check(rail_sign.station_name == interchange.interchange_name and rail_sign.parent_station == rail, "Runtime rail signs use their stop's shared interchange name")
	self.check(rail_sign.texture.get_local_scene().get_node(rail_sign.texture.viewport_path) == rail_sign.get_node("SubViewport"), "Legacy rail scene overrides resolve the correct sign viewport")
	var bus: BusStop3D = coordinator.road_stops.containers_by_num[13]
	self.check(bus.station == road and bus.get_node("Model").get_child_count() == 2, "BOTH creates two shelters for one logical bus stop")
	self.check(bus.get_node("Model/Shelter").global_position.distance_to(bus.get_node("Model/OppositeShelter").global_position) > 7.9, "The two shelters occupy opposite road sides")
	test_legacy_passenger_destinations(interchange)
	var bus_sign: StationSign3D = bus.get_node("StationSign3D")
	var inventory: GoodsInventory = interchange.inventory
	inventory.change_stack(&"passenger", rail.num, 2)
	inventory.add_goods_amount(GoodsAmount.new("lumber", 4))
	for sign_3d: StationSign3D in [rail_sign, bus_sign]:
		self.check(sign_3d.visibility_range_end == 200.0 and sign_3d.visibility_range_end_margin == 0.0, "Runtime stop signs have a 200 m visibility cutoff")
		self.check(sign_3d.station_inventory == inventory and sign_3d.station_sign_ui.passengers_amount == 2 \
			and sign_3d.station_sign_ui.cargo_amount == 4, "Rail and bus signs update from the same interchange inventory")
	inventory.change_stack(&"passenger", rail.num, -2)
	inventory.remove_goods_amount(GoodsAmount.new("lumber", 4))
	check(test_shared_stock(rail_view, bus), "Shared-stock test completed")
	check(test_station_dialogs(link.station3d, bus), "Station dialogs test completed")
	coordinator.road_stops.spawn_stops()
	self.check(coordinator.road_stops.containers_by_num.size() == 1, "Repeated road spawning does not duplicate stops")
	self.check(coordinator.load_map_data(key) == ERR_ALREADY_IN_USE, "Repeated map loading cannot duplicate network resources")
	self.test_catchments(rail, road, town)
	self.check(self.test_missing_anchors(coordinator.rails.track_storage, coordinator.roads.storage), "Invalid anchors rejected before stop publication")
	coordinator.free()
	coordinator = null
	self.check(Managers.interchanges == null and Managers.road_stops == null and town.stations.is_empty(), "Session cleanup releases services and town back-references")
	for filename: String in ["interchanges.json", "tracks.json", "roads.json", "vehicles_depots.json"]:
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute("res://world/" + key)
	GlobalState.station_objs.clear()
	return true

func test_legacy_passenger_destinations(interchange: InterchangeData) -> void:
	var stock := GoodsInventory.new()
	stock.add_goods_amount(GoodsAmount.new("passenger", 4))
	# Stops 12 and 13 share interchange 7. Stop 999 was deleted from the map.
	stock.passenger_destinations = {&"passenger": {12: 1.0, 13: 2.0, 999: 1.0}}
	check(stock.stack_amount(&"passenger", interchange.num) == 3, "Old stop targets merge into the destination interchange")
	check(stock.stack_amount(&"passenger") == 1 and stock.get_amount("passenger") == 4, "A deleted legacy target becomes unassigned without losing stock")

func test_shared_stock(rail_view: RailStation3D, bus: BusStop3D) -> bool:
	var interchange: InterchangeData = rail_view.station.interchange
	var rail_access: InventoryEndpoint = InventoryEndpoint.from_node(rail_view)
	var road_access: InventoryEndpoint = InventoryEndpoint.from_node(bus)
	check(rail_access.inventory() == interchange.inventory and road_access.inventory() == interchange.inventory, "Rail and road access the interchange's inventory")
	check(rail_access.position() != road_access.position(), "Each endpoint retains its physical access position")
	check(coordinator.interchanges.by_num[8].inventory != interchange.inventory, "Other interchanges own independent stock")

	# Deliver a batch through the bus stop and run the real industry's timer callback.
	var data := IndustryData.new("SAWMILL", bus.global_position)
	data.ind_name = "Test sawmill"
	interchange.connections.connect_industry(data, [bus.station])
	var industry := Industry3D.new()
	industry.industry = data
	var collider := IndustryCollider.new()
	industry.add_child(collider)
	add_child(industry)
	var industry_access: InventoryEndpoint = InventoryEndpoint.from_node(industry)
	check(industry_access.inventory() == rail_access.inventory(), "The industry exposes the same stock for manual transfers")

	var delivery := Node3D.new()
	delivery.add_child(InventoryContainer.new())
	add_child(delivery)
	delivery.global_position = bus.global_position
	var cargo: InventoryEndpoint = InventoryEndpoint.from_node(delivery)
	cargo.inventory().add_goods_amount(GoodsAmount.new("lumber", 9))
	var lumber := InventoryStack.new(&"lumber", 9)
	check(InventoryTransferService.transfer(cargo, road_access, lumber, 9).is_empty(), "Road access accepts a delivery of sawmill input")

	var production: IndustryProduction = industry.get_node("Production")
	check(test_live_industry_recipe(collider, production), "Industry dialog test completed")
	check(rail_access.inventory().get_amount("lumber") == 0, "Sawmill consumes its batch from the interchange")
	check(rail_access.inventory().get_amount("boards") == 3, "The rail stop can load the sawmill's output")

	# Keep this fixture out of the catchment checks that follow.
	interchange.connections.clear_industries()
	check(industry_access.inventory() != interchange.inventory, "An unconnected industry uses its local stock")
	GlobalState.industries.erase(data)
	industry.free()
	delivery.free()
	return true

func test_live_industry_recipe(collider: IndustryCollider, production: IndustryProduction) -> bool:
	var handler := BaseEntityClickHandler.new()
	add_child(handler)
	check(handler.handle_click(collider), "Clicking the sawmill opens its recipe dialog")
	var dialog := UiState.current_diag as IndustryDialog
	if dialog == null:
		handler.free()
		return false
	var inputs: ItemList = dialog.get_node("%IndustryConsumption").get_node("%GoodsTable")
	var outputs: ItemList = dialog.get_node("%IndustryProduction").get_node("%GoodsTable")
	check(inputs.get_item_text(0).contains("9 in stock"), "Industry dialog sees the delivery before the batch")

	# Fire the real timer without waiting for five seconds of wall time.
	var timer: Timer = production.get_child(0)
	timer.timeout.emit()
	check(inputs.get_item_text(0).contains("0 in stock"), "The input table refreshes after consumption")
	check(outputs.get_item_text(0).contains("3 in stock"), "The output table refreshes after production")

	dialog.free()
	handler.free()
	return true

func test_station_dialogs(rail_link: NodeStationLink3D, bus: BusStop3D) -> bool:
	var handler := BaseEntityClickHandler.new()
	add_child(handler)
	var rail_collider: StationCollider = rail_link.get_node("StationBuilding3D/StationBody")
	var road_collider: StationCollider = bus.get_node("Model/OppositeShelter/ShelterClick")

	# Both physical station models open the same information through the click handler.
	for collider: StationCollider in [rail_collider, road_collider]:
		check(handler.handle_click(collider), "Clicking a station opens its information dialog")
		var dialog := UiState.current_diag as ModalGameDialog
		if dialog == null:
			continue
		var headline: Label = dialog.get_node("%Headline")
		var city: Label = dialog.get_node("%TownName")
		var connections: ItemList = dialog.get_node("%Connections")
		var goods: ItemList = dialog.get_node("%Inventory")
		check(headline.text == bus.station.station_name, "Station dialog shows the interchange name")
		check(city.visible and city.text == bus.station.town_name, "The station name has a city heading")
		check(connections.item_count == 2, "Station dialog lists both physical stops")
		check(goods.item_count == 1 and goods.get_item_text(0).contains("Boards"), "Station dialog shows stock from production")

		# Stock changes while the dialog is open should refresh its inventory list.
		var inventory: GoodsInventory = bus.get_inventory()
		inventory.add_goods_amount(GoodsAmount.new("milk", 1.5))
		check(goods.item_count == 2 and goods.get_item_text(1).contains("Milk"), "The dialog refreshes when milk arrives")
		inventory.remove_goods_amount(GoodsAmount.new("milk", 1.5))
		inventory.change_stack(&"passenger", bus.station.interchange.num, 1)
		var passenger_row: String = goods.get_item_text(goods.item_count - 1)
		check(passenger_row.contains(city.text) and passenger_row.contains(headline.text), "Passenger destinations show both city and station")
		inventory.change_stack(&"passenger", bus.station.interchange.num, -1)
		dialog.get_node("%CloseButton").pressed.emit()
		check(dialog.is_queued_for_deletion(), "Close button dismisses the station dialog")
		dialog.free()
	handler.free()
	return true

func test_catchments(rail: RailStationData, road: RoadStationData, town: TownData) -> void:
	var catalog: InterchangesLoader = coordinator.interchanges
	self.check(catalog.find_access(Vector3(210, 2, 20)).stops == [rail], "Catchment includes exactly 200 metres and excludes stops outside the radius")
	self.check(catalog.find_access(Vector3(210.01, 2, 20)).is_empty(), "Buildings beyond every stop's catchment remain disconnected")
	var house := Residence3D.new()
	house.res_bld_obj = ResidenceBuildingData.new(3, null)
	self.add_child(house)
	house.position = Vector3(10, 2, 24)
	town.res_bld_containers.append(house)
	coordinator.residence_connector.reassign_town_buildings_to_stations(town)
	coordinator.residence_connector.reassign_town_buildings_to_stations(town)
	self.check(house.res_bld_obj.connected_interchange == rail.interchange and house.res_bld_obj.reachable_stops == [road, rail], "One residence membership retains both reachable modes, nearest first")
	self.check(rail.interchange.connections.houses.size() == 1, "Repeated reassignment never duplicates a house")
	rail.position = Vector3(1000, 2, 20)
	coordinator.residence_connector.reassign_town_buildings_to_stations(town)
	self.check(house.res_bld_obj.reachable_stops == [road], "A road-only catchment still connects the residence")
	var industry := IndustryData.new(GameTypes.industry_types[0].key, road.position)
	coordinator.industry_connector.has_connected = false
	coordinator.industry_connector.connect_industries()
	self.check(industry.station_connection != null and industry.station_connection.interchange == road.interchange and industry.station_connection.station == road, "Industries connect to road-only interchange access")
	industry.pos = Vector3(3000, 0, 0)
	coordinator.industry_connector.has_connected = false
	coordinator.industry_connector.connect_industries()
	self.check(industry.station_connection == null and road.interchange.connections.industries.is_empty(), "Industry reassignment clears out-of-range connections")
	GlobalState.industries.erase(industry)
	house.position = Vector3(3000, 0, 0)
	coordinator.residence_connector.reassign_town_buildings_to_stations(town)
	self.check(house.res_bld_obj.connected_interchange == null and road.interchange.connections.houses.is_empty(), "Lost catchment clears residence membership")
	GlobalState.res_blds.erase(house.res_bld_obj)
	town.res_bld_containers.erase(house)
	house.free()
	rail.position = Vector3(10, 2, 20)

func test_missing_anchors(rails: RailTrackStore, roads: RoadStore) -> bool:
	var loader := InterchangesLoader.new()
	print("Checking missing stop anchors; the following validation errors are expected.")
	for domain: String in ["RAIL", "ROAD"]:
		for field: String in ["number", "index"]:
			var source: Array = self.definitions()
			var stop: Dictionary = source[0]["stops"][0 if domain == "RAIL" else 1]
			stop["nodeIndex" if field == "index" else ("trackNum" if domain == "RAIL" else "roadNum")] = 999
			self.check(loader.load_definitions(source) == OK, "Anchor shape is valid before network resolution")
			self.check(loader.validate_anchors(rails, roads) != OK and loader.stops_by_num.is_empty(), "Missing infrastructure/index publishes no partial stops")
	loader.free()
	return true

func test_migrated_maps() -> bool:
	for key: String in ["franzburger", "harzmountains", "mpsb", "sachalin"]:
		var services: WorldServicesCoordinator = SERVICES.instantiate()
		self.add_child(services)
		self.check(services.initialize() == OK, "Services initialize for migrated map: " + key)
		self.check(services.load_map_data(key) == OK, "Real data pipeline loads migrated map: " + key)
		var catalog: InterchangesLoader = services.interchanges
		var rails: RailTrackStore = services.rails.track_storage
		var roads: RoadStore = services.roads.storage
		for definition: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://world/%s/jsondata/tracks.json" % key)):
			for point: Dictionary in definition["points"]:
				self.check(not point.has("station"), "Rail JSON contains geometry, not duplicate stop definitions")
		self.check(catalog.validate_anchors(rails, roads) == OK, "All migrated stop references resolve: " + key)
		var rail_count: int = 0
		var road_count: int = 0
		for definition: Dictionary in catalog.stop_definitions:
			if definition["domain"] == "RAIL":
				rail_count += 1
				var rail_stop: RailStationData = catalog.stops_by_num[int(definition["num"])]
				self.check(rail_stop.station_type == definition.get("type", "STATION_PASS"), "Rail stop retains its authored passenger/goods type: " + key)
			else: road_count += 1
		self.check([catalog.interchanges.size(), rail_count, road_count] == authored_station_counts(key), "Loading preserves every authored interchange and stop: " + key)
		self.check(catalog.stops_by_num.size() == rail_count + road_count, "Every physical stop is registered exactly once: " + key)
		for stop: AbstractStation in catalog.stops_by_num.values():
			self.check(stop.interchange != null and stop.interchange.stops.has(stop), "Loaded stop has its parent interchange: " + key)
		services.free()
		# These fixtures intentionally keep the stores for assertions. Release
		# their infrastructure back-references rather than leaking every map node.
		for track: RailTrackData in rails.get_all():
			for node: RailNodeData in track.nodes:
				node.parent_track = null
				node.fork = null
			track.nodes.clear()
		for road: RoadData in roads.get_all():
			for node: RoadNode in road.nodes:
				node.parent_track = null
				node.cross = null
			road.nodes.clear()
			road.crosses.clear()
		GlobalState.roads.clear()
	return true

## Map authors can add stops without changing this loader regression test.
func authored_station_counts(map_key: String) -> Array[int]:
	var path: String = "res://world/%s/jsondata/interchanges.json" % map_key
	var authored: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var counts: Array[int] = [authored.size(), 0, 0]
	for interchange: Dictionary in authored:
		for stop: Dictionary in interchange["stops"]:
			counts[1 if stop["domain"] == "RAIL" else 2] += 1
	return counts
