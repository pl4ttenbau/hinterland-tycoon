extends Node

var failures: int = 0
var stations: Array[RoadStationData] = []

func _ready() -> void:
	self._run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		self.failures += 1
		push_error(message)

func _run() -> void:
	self.check(self.test_json(), "Road stop JSON checks completed")
	self.check(self.test_scene(), "Bus stop scene checks completed")
	self.check(self.test_editor_labels(), "Editor stop label checks completed")
	# Existing station connections hold a back-reference to their parent Resource.
	for station: RoadStationData in self.stations:
		station.connections.parent = null
	self.stations.clear()
	print("Bus stop tests: %d failures" % self.failures)
	get_tree().quit(1 if self.failures > 0 else 0)

func make_station(data: Dictionary) -> RoadStationData:
	var station: RoadStationData = RoadStationData.of_dict(data)
	if station != null:
		self.stations.append(station)
	return station

func test_json() -> bool:
	var record: Dictionary = JSON.parse_string('{"num":0,"roadNum":0,"nodeIndex":0,"roadSide":"RIGHT"}')
	var stop: RoadStationData = self.make_station(record)
	self.check(stop != null and stop is AbstractStation, "A minimal road record creates station data")
	self.check(stop.num == 0 and stop.road_num == 0 and stop.node_index == 0, "JSON numbers accept stop ID, road ID and node index zero")
	self.check(stop.road_side == Enums.RoadSide.RIGHT and stop.town_num == -1 \
		and stop.station_name.is_empty() and not stop.hide_building, "Minimal records retain optional station defaults")
	self.check(not record.has("name") and record["roadSide"] == "RIGHT", "Parsing leaves the source record unchanged")
	for side: String in ["LEFT", "RIGHT", "BOTH"]:
		var variant: Dictionary = record.duplicate(true)
		variant["roadSide"] = side
		self.check(self.make_station(variant).road_side == Enums.RoadSide[side], "All three road sides load")
	var full: Dictionary = record.duplicate(true)
	full.merge({"name": "Village", "townNum": 3, "townName": "Town", "type": "BUS_STOP", "hideBuilding": true})
	var named: RoadStationData = self.make_station(full)
	self.check(named.station_name == "Village" and named.town_num == 3 and named.town_name == "Town" \
		and named.station_type == "BUS_STOP" and named.hide_building, "Optional metadata follows rail station conventions")
	print("Checking invalid road stops; the following validation errors are expected.")
	for field: String in ["num", "roadNum", "nodeIndex", "roadSide"]:
		var missing: Dictionary = record.duplicate(true)
		missing.erase(field)
		self.check(self.make_station(missing) == null, "Each of the four core fields is required")
	for fields: Dictionary in [
		{"num": -1}, {"num": true}, {"roadNum": "1"}, {"nodeIndex": 0.5},
		{"nodeIndex": null}, {"roadSide": "right"}, {"roadSide": 1},
		{"name": null}, {"townNum": -1}, {"townName": 3}, {"type": false}, {"hideBuilding": "true"}
	]:
		var invalid: Dictionary = record.duplicate(true)
		invalid.merge(fields, true)
		self.check(self.make_station(invalid) == null, "Invalid field values are rejected")
	return true

func test_scene() -> bool:
	var packed: PackedScene = load("res://scenes/subscenes/infr/station/bus_stop_3d.tscn")
	var stop: BusStop3D = packed.instantiate()
	var other: BusStop3D = packed.instantiate()
	var first: RoadStationData = self.make_station({"num": 1, "roadNum": 4, "nodeIndex": 0, "roadSide": "LEFT"})
	var second: RoadStationData = self.make_station({"num": 2, "roadNum": 4, "nodeIndex": 1, "roadSide": "RIGHT", "hideBuilding": true})
	first.station_name = "First stop"
	second.station_name = "Second stop"
	first.position = Vector3(4, 2, 6)
	second.position = Vector3(-3, 1, 9)
	stop.station = first
	var parent := Node3D.new()
	self.add_child(parent)
	parent.position = Vector3(40, 3, 20)
	parent.rotation.y = 0.5
	parent.add_child(stop)
	parent.add_child(other)
	self.check(stop.entity == first and stop.global_position.is_equal_approx(first.position), "Pre-tree assignment resolves world position under a transformed parent")
	self.check(stop.get_node("Model").get_child_count() > 0, "Reusable bus stop scene includes the authored mesh")
	var inventory: GoodsInventory = stop.get_inventory()
	var other_inventory: GoodsInventory = other.get_inventory()
	self.check(inventory != null and inventory.amount_max == 60.0, "Bus stops expose the existing station inventory contract")
	self.check(inventory != other_inventory and inventory.storage != other_inventory.storage, "Each bus stop owns independent inventory and storage")
	var sign: StationSign3D = stop.get_node("StationSign3D")
	self.check(sign.parent_station == first and sign.station_name == "First stop" and sign.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Runtime road stops use the existing station billboard")
	self.check(sign.texture is ViewportTexture and sign.texture.get_local_scene().get_node(sign.texture.viewport_path) == sign.get_node("SubViewport"), "Each sign resolves its own viewport texture")
	inventory.storage.total_passengers = 3
	inventory.storage.total_cargo = 4
	inventory.goods_change.emit()
	self.check(sign.station_sign_ui.passengers_amount == 3 and sign.station_sign_ui.cargo_amount == 4, "Station signs display live inventory amounts")
	first.position = Vector3(8, 3, 7)
	self.check(stop.global_position.is_equal_approx(first.position), "Station position events move the view")
	stop.station = second
	stop.station = second
	self.check(not first.positioned.is_connected(stop._on_station_positioned), "Reassignment releases the previous data signal")
	self.check(second.positioned.get_connections().size() == 1, "Assigning the same station does not duplicate listeners")
	self.check(not stop.get_node("Model").visible and stop.global_position.is_equal_approx(second.position), "Reassignment updates world position and building visibility")
	self.check(sign.visible and sign.parent_station == second and sign.station_name == "Second stop", "Hidden station buildings retain a named billboard")
	self.check(inventory.goods_change.get_connections().filter(func(connection: Dictionary) -> bool: return connection.callable == sign._on_inventory_change).size() == 1, "Repeated assignment does not duplicate inventory listeners")
	first.position = Vector3(99, 99, 99)
	self.check(stop.global_position.is_equal_approx(second.position), "The previous station cannot move the reassigned view")
	parent.remove_child(stop)
	self.check(second.positioned.get_connections().is_empty(), "Tree exit disconnects data signals")
	second.position = Vector3(2, 5, 3)
	parent.add_child(stop)
	self.check(stop.global_position.is_equal_approx(second.position), "Reentering the tree reconnects and catches up to data changes")
	stop.station = null
	self.check(stop.entity == null and second.positioned.get_connections().is_empty() \
		and stop.get_node("Model").visible, "Clearing station data disconnects cleanly and restores the model")
	self.check(not sign.visible, "Clearing station data hides its billboard")
	stop.station = second
	parent.free()
	self.check(second.positioned.get_connections().is_empty(), "Deleting the view leaves no signal listeners")
	return true

func test_editor_labels() -> bool:
	var key: String = "__stop_labels_test_%d" % OS.get_process_id()
	var folder: String = "res://world/%s/jsondata" % key
	DirAccess.make_dir_recursive_absolute(folder)
	var fixtures: Dictionary = {
		"interchanges.json": [{"num": 7, "name": "Shared interchange", "townNum": 3, "stops": [
			{"num": 12, "domain": "RAIL", "trackNum": 4, "nodeIndex": 0},
			{"num": 13, "domain": "ROAD", "roadNum": 42, "nodeIndex": 1, "roadSide": "BOTH"}
		]}],
		"tracks.json": [{"num": 4, "points": [{"pos": [10, 2, 20]}, {"pos": [30, 2, 20]}]}],
		"roads.json": [{"num": 42, "points": [{"pos": [10, 2, 25]}, {"pos": [30, 2, 25]}]}]
	}
	for filename: String in fixtures:
		var file := FileAccess.open(folder.path_join(filename), FileAccess.WRITE)
		file.store_string(JSON.stringify(fixtures[filename]))
		file.close()
	var world := WorldEditorObjects.new()
	world.map_key = key
	self.add_child(world)
	world.transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(100, 3, 20))
	var store := EditorStopLabelsStore.new()
	var history_suite: GDScript = load("res://tests/infr_json_suite.gd")
	var history: RefCounted = history_suite.History.new()
	var result: Dictionary = store.load_world(world, history)
	self.check(result.ok and result.count == 2, "Editor JSON action creates both rail and road labels")
	var container: Node3D = world.get_node("EditorStops")
	var rail: StationSign3D = container.get_node("RailStop_12")
	var road: StationSign3D = container.get_node("RoadStop_13")
	self.check(rail.station_name == "Shared interchange" and road.station_name == rail.station_name, "Both stop labels show the interchange name")
	self.check(rail.parent_station == null and road.parent_station == null, "Editor labels contain no simulation station data")
	self.check(rail.global_position.is_equal_approx(Vector3(10, 17, 20)) and road.global_position.is_equal_approx(Vector3(30, 17, 25)), "Labels resolve exact JSON anchors under a transformed editor root")
	self.check(rail.owner == world and road.owner == world and container.owner == world, "Editor labels are owned by the edited scene for Ctrl+S")
	self.check(world.find_children("*", "BusStop3D", true, false).is_empty() and world.find_children("*", "NodeStationLink3D", true, false).is_empty(), "Editor loading creates labels without shelters or platforms")
	history.undo.undo()
	self.check(container.get_child_count() == 0, "Undo removes the loaded stop labels")
	history.undo.redo()
	self.check(container.get_child_count() == 2 and rail.station_sign_ui.station_name == "Shared interchange", "Redo restores labels and their panel text")
	self.check(store.load_world(world, history).ok and container.get_child_count() == 2, "Reload replaces labels instead of duplicating BOTH road stops")
	var packed := PackedScene.new()
	self.check(packed.pack(world) == OK, "Generated label previews can be packed with EditorObjects")
	var restored: WorldEditorObjects = packed.instantiate()
	self.check(restored.get_node("EditorStops/RailStop_12").station_name == "Shared interchange", "Saved editor previews retain station names")
	self.add_child(restored)
	self.check(not restored.has_node("EditorStops"), "Runtime drops saved editor signs before creating live station views")
	restored.free()
	var old_label: Node = container.get_child(0)
	fixtures["interchanges.json"][0]["stops"][0]["nodeIndex"] = 99
	var broken := FileAccess.open(folder.path_join("interchanges.json"), FileAccess.WRITE)
	broken.store_string(JSON.stringify(fixtures["interchanges.json"]))
	broken.close()
	self.check(not store.load_world(world, history).ok and container.get_child(0) == old_label, "Invalid anchors preserve the previously loaded labels")
	history.undo.clear_history()
	world.free()
	for filename: String in fixtures:
		DirAccess.remove_absolute(folder.path_join(filename))
	DirAccess.remove_absolute(folder)
	DirAccess.remove_absolute("res://world/" + key)
	return true
