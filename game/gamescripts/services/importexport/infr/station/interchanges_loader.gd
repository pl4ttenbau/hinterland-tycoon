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
## The file the catalog came from, "" when loaded from records (tests). The stop export writes back to it.
var source_path: String = ""

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
	error = self.load_definitions(parser.data)
	if error == OK:
		self.source_path = path
	return error

## Validate the entire catalog before publishing any parent. Stop Resources are
## deliberately not constructed here: every interchange must exist first.
func load_definitions(records: Variant) -> Error:
	var error: Error = validate_definitions(records)
	if error != OK:
		return error
	self.clear()
	for record: Dictionary in records:
		_create_interchange(record)
	self.is_loaded = true
	self.interchanges_loaded.emit(self.interchanges)
	return OK

static func validate_definitions(records: Variant) -> Error:
	if not records is Array:
		return _invalid("Interchange catalog must contain an array")
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

static func _validate_interchange_record(record: Variant, parent_ids: Dictionary) -> Error:
	# The record itself (fields, types) is the mapper's; numbering across records is the catalog's.
	var problem: String = InterchangeMapper.validation_error(record)
	if not problem.is_empty():
		return _invalid(problem)
	var parent_id: int = int(record["num"])
	if parent_ids.has(parent_id):
		return _invalid("Duplicate interchange number %d" % parent_id)
	parent_ids[parent_id] = true
	return OK

static func _validate_stop_record(stop: Variant, stop_ids: Dictionary, rail_anchors: Dictionary) -> Error:
	var problem: String = StopMapper.validation_error(stop)
	if not problem.is_empty():
		return _invalid(problem)
	for shared_field: String in ["name", "townNum", "townName", "interchangeNum"]:
		if stop.has(shared_field):
			return _invalid("Stop %s belongs to its parent interchange" % shared_field)
	var stop_id: int = int(stop["num"])
	if stop_ids.has(stop_id):
		return _invalid("Duplicate stop number %d across rail/road stops" % stop_id)
	stop_ids[stop_id] = true
	return _validate_rail_place(stop, rail_anchors)

## Same track, node and offset (to the centimetre): two platforms in one place. Road stops are not
## checked: two of them may share a place, e.g. one per direction.
static func _validate_rail_place(stop: Dictionary, rail_anchors: Dictionary) -> Error:
	if stop["domain"] != "RAIL":
		return OK
	var place: LineAnchor = LineAnchor.from_dict(stop)
	var key: String = "%d:%s" % [int(stop["trackNum"]), place]
	if rail_anchors.has(key):
		return _invalid("Two rail stops use track %d at %s" % [int(stop["trackNum"]), place])
	rail_anchors[key] = true
	return OK

func _create_interchange(record: Dictionary) -> void:
	# Validated with the whole catalog before, so the mapper cannot fail here.
	var interchange: InterchangeData = InterchangeMapper.interchange_from_dict(record)
	self.interchanges.append(interchange)
	self.by_num[interchange.num] = interchange
	for stop: Dictionary in record["stops"]:
		var definition: Dictionary = stop.duplicate(true)
		# Membership comes from nesting, never from a conflicting child field.
		definition["interchangeNum"] = interchange.num
		self.stop_definitions.append(definition)

## Infrastructure must be loaded before this pass. Fail before either stop loader
## can register a partial rail/road network.
func validate_anchors(rails: RailTrackStore, roads: RoadStore) -> Error:
	if not self.is_loaded:
		return ERR_UNCONFIGURED
	for definition: Dictionary in self.stop_definitions:
		var number_key: String = "trackNum" if definition["domain"] == "RAIL" else "roadNum"
		var lookup: Dictionary = rails._by_id if definition["domain"] == "RAIL" else roads._by_id
		var infrastructure: AbstractInfrLine = lookup.get(int(definition[number_key]))
		if infrastructure == null or int(definition["nodeIndex"]) >= infrastructure.nodes.size():
			return _invalid("Stop %d references missing infrastructure or node" % int(definition["num"]))
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
			stop.connected_town = town
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
	self.source_path = ""

func _disconnect_interchange(interchange: InterchangeData) -> void:
	interchange.connections.clear_houses()
	interchange.connections.clear_industries()
	for stop: AbstractStation in interchange.stops:
		var town: TownData = stop.connected_town
		if town != null:
			town.stations.erase(stop)
		stop.connected_town = null
	interchange.stops.clear()
	interchange.connected_town = null

static func _invalid(message: String) -> Error:
	push_error(message)
	return ERR_INVALID_DATA

func _exit_tree() -> void:
	self.clear()
