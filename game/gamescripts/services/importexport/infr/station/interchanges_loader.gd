@icon("res://assets/icons/icon_station_white.png")
class_name InterchangesLoader extends Node

const CATALOG_PATH_FORMAT := "res://world/%s/jsondata/interchanges.json"

signal interchanges_loaded(interchanges: Array[InterchangeData])
signal stops_linked()

var interchanges: Array[InterchangeData] = []
var by_num: Dictionary = {}
## One manual stop-ID namespace across both domains, independent of parent IDs.
var stops_by_num: Dictionary = {}
var stop_definitions: Array[Dictionary] = []
var is_loaded: bool = false

func load_interchanges(map_key: String, catalog_path: String = "") -> Error:
	var path: String = catalog_path if not catalog_path.is_empty() else CATALOG_PATH_FORMAT % map_key
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open interchange catalog: %s" % path)
		return FileAccess.get_open_error()
	var parser := JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	if error != OK:
		push_error("Invalid interchange JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return error
	return self.load_definitions(parser.data)

## Validate the entire catalog before publishing any parent. Stop Resources are
## deliberately not constructed here: every interchange must exist first.
func load_definitions(records: Variant) -> Error:
	if not records is Array:
		return self._invalid("Interchange catalog must contain an array")
	var error: Error = _validate_definitions(records)
	if error != OK:
		return error
	self.clear()
	for record: Dictionary in records:
		_create_interchange(record)
	self.is_loaded = true
	self.interchanges_loaded.emit(self.interchanges)
	return OK

func _validate_definitions(records: Array) -> Error:
	var parent_ids: Dictionary = {}
	var stop_ids: Dictionary = {}
	var rail_anchors: Dictionary = {}
	for record: Variant in records:
		var error: Error = _validate_interchange_record(record, parent_ids)
		if error != OK:
			return error
		for stop: Variant in record["stops"]:
			error = _validate_stop_record(stop, stop_ids, rail_anchors)
			if error != OK:
				return error
	return OK

func _validate_interchange_record(record: Variant, parent_ids: Dictionary) -> Error:
	if not record is Dictionary or not InterchangeData.is_valid_num(record.get("num")) \
			or not record.get("name") is String or record["name"].strip_edges().is_empty() \
			or not InterchangeData.is_valid_num(record.get("townNum")) \
			or not record.get("townName", "") is String or not record.get("stops") is Array:
		return self._invalid("Interchange requires num, name, townNum and a stops array")
	var parent_id: int = int(record["num"])
	if parent_ids.has(parent_id):
		return self._invalid("Duplicate interchange number %d" % parent_id)
	parent_ids[parent_id] = true
	return OK

func _validate_stop_record(stop: Variant, stop_ids: Dictionary, rail_anchors: Dictionary) -> Error:
	if not stop is Dictionary or not InterchangeData.is_valid_num(stop.get("num")) \
			or not InterchangeData.is_valid_num(stop.get("nodeIndex")) \
			or stop.get("domain") not in ["RAIL", "ROAD"]:
		return self._invalid("Stop requires num, nodeIndex and domain RAIL or ROAD")
	for shared_field: String in ["name", "townNum", "townName", "interchangeNum"]:
		if stop.has(shared_field):
			return self._invalid("Stop %s belongs to its parent interchange" % shared_field)
	var stop_id: int = int(stop["num"])
	if stop_ids.has(stop_id):
		return self._invalid("Duplicate stop number %d across rail/road stops" % stop_id)
	stop_ids[stop_id] = true
	var error: Error = _validate_stop_anchor(stop, rail_anchors)
	if error != OK:
		return error
	if stop.has("hideBuilding") and not stop["hideBuilding"] is bool:
		return self._invalid("Stop hideBuilding must be boolean")
	if stop.has("type") and not stop["type"] is String:
		return self._invalid("Stop type must be a string")
	return OK

func _validate_stop_anchor(stop: Dictionary, rail_anchors: Dictionary) -> Error:
	var anchor_key: String = "trackNum" if stop["domain"] == "RAIL" else "roadNum"
	if not InterchangeData.is_valid_num(stop.get(anchor_key)):
		return self._invalid("Stop %d requires %s" % [int(stop["num"]), anchor_key])
	if stop["domain"] == "RAIL":
		var anchor := Vector2i(int(stop["trackNum"]), int(stop["nodeIndex"]))
		if rail_anchors.has(anchor):
			return self._invalid("Two rail stops use track/node %s" % anchor)
		rail_anchors[anchor] = true
	elif not stop.get("roadSide") is String or not Enums.RoadSide.has(stop["roadSide"]):
		return self._invalid("Road stop %d requires LEFT, RIGHT or BOTH" % int(stop["num"]))
	return OK

func _create_interchange(record: Dictionary) -> void:
	var interchange := InterchangeData.new()
	interchange.num = int(record["num"])
	interchange.interchange_name = record["name"]
	interchange.town_num = int(record["townNum"])
	interchange.town_name = record.get("townName", "")
	self.interchanges.append(interchange)
	self.by_num[interchange.num] = interchange
	for stop: Dictionary in record["stops"]:
		var definition: Dictionary = stop.duplicate(true)
		# Membership comes from nesting, never from a conflicting child field.
		definition["interchangeNum"] = interchange.num
		self.stop_definitions.append(definition)

## Infrastructure must be loaded before this pass. Fail before either stop loader
## can register a partial rail/road network or overwrite a RailNode.station link.
func validate_anchors(rails: RailTrackStore, roads: RoadStore) -> Error:
	if not self.is_loaded:
		return ERR_UNCONFIGURED
	for definition: Dictionary in self.stop_definitions:
		var number_key: String = "trackNum" if definition["domain"] == "RAIL" else "roadNum"
		var lookup: Dictionary = rails._by_id if definition["domain"] == "RAIL" else roads._by_id
		var infrastructure: AbstractTrack = lookup.get(int(definition[number_key]))
		if infrastructure == null or int(definition["nodeIndex"]) >= infrastructure.nodes.size():
			return self._invalid("Stop %d references missing infrastructure or node" % int(definition["num"]))
	return OK

func register_stop(stop: AbstractStation, interchange_num: int) -> Error:
	if not self.is_loaded or not self.by_num.has(interchange_num):
		return ERR_UNCONFIGURED
	if self.stops_by_num.has(stop.num):
		return ERR_ALREADY_EXISTS
	stop.interchange = self.by_num[interchange_num]
	stop.interchange.stops.append(stop)
	self.stops_by_num[stop.num] = stop
	return OK

func next_interchange_num() -> int:
	var result: int = 0
	for number: int in by_num:
		result = maxi(result, number + 1)
	return result

func next_stop_num() -> int:
	var result: int = 0
	for number: int in stops_by_num:
		result = maxi(result, number + 1)
	return result

func create_runtime_interchange(title: String, town: TownData) -> InterchangeData:
	if not is_loaded or title.strip_edges().is_empty() or town == null:
		return null
	var interchange := InterchangeData.new()
	interchange.num = next_interchange_num()
	interchange.interchange_name = title.strip_edges()
	interchange.town_num = town.num
	interchange.town_name = town.town_name
	interchange.connected_town = town
	interchanges.append(interchange)
	by_num[interchange.num] = interchange
	return interchange

## A building belongs once to the interchange with the closest reachable stop.
## Retain every reachable stop in that interchange for later boarding/routing.
func find_access(position: Vector3, radius: float = 200.0) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for interchange: InterchangeData in interchanges:
		var reachable: Array[AbstractStation] = interchange.reachable_stops(position, radius)
		if reachable.is_empty():
			continue
		var distance: float = position.distance_squared_to(reachable[0].get("position"))
		if best.is_empty() or distance < best_distance or (is_equal_approx(distance, best_distance) and interchange.num < best.interchange.num):
			best = {"interchange": interchange, "stops": reachable}
			best_distance = distance
	return best

func _on_map_towns_loaded(towns: Array[TownData]) -> void:
	var towns_by_num: Dictionary = {}
	for town: TownData in towns:
		towns_by_num[town.num] = town
	for interchange: InterchangeData in self.interchanges:
		var town: TownData = towns_by_num.get(interchange.town_num)
		interchange.connected_town = town
		if town == null:
			continue
		if interchange.town_name.is_empty():
			interchange.town_name = town.town_name
		for stop: AbstractStation in interchange.stops:
			stop.set("connected_town", town)
			town.connect_new_station(stop)

func clear() -> void:
	# Break Resource back-references explicitly when a session is unloaded.
	for interchange: InterchangeData in self.interchanges:
		_disconnect_interchange(interchange)
	self.interchanges.clear()
	self.by_num.clear()
	self.stops_by_num.clear()
	self.stop_definitions.clear()
	self.is_loaded = false

func _disconnect_interchange(interchange: InterchangeData) -> void:
	interchange.connections.clear_houses()
	interchange.connections.clear_industries()
	interchange.connections.parent = null
	for stop: AbstractStation in interchange.stops:
		var town: TownData = stop.get("connected_town")
		if town != null:
			town.stations.erase(stop)
		stop.set("connected_town", null)
		stop.interchange = null
		stop.connections.parent = null
	interchange.stops.clear()
	interchange.connected_town = null

func _invalid(message: String) -> Error:
	push_error(message)
	return ERR_INVALID_DATA

func _exit_tree() -> void:
	self.clear()
