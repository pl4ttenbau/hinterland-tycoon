extends RefCounted
## StopMapper and InterchangeMapper: interchanges.json records <-> stop and interchange Resources.
## A record read and written back must come out exactly as it was, fields, defaults and key order
## included, so writing a catalog never rewrites records nobody touched.

const MAPS: Array[String] = ["franzburger", "harzmountains", "mpsb", "sachalin"]

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run(_tree: SceneTree) -> int:
	for test: Callable in [test_real_maps_round_trip, test_all_fields, test_defaults, test_validation, test_catalog_accepts]:
		check(test.call() == true, "%s completed without runtime errors" % test.get_method())
	print("Stop mapper tests: %d failures" % failures)
	return 1 if failures > 0 else 0

## JSON text with key order kept and whole numbers as integers: JSON parsing turns every number into a
## float, while the mappers write ints, and only the text shows the key order.
static func text(value: Variant) -> String:
	return JSON.stringify(_ints(value), "", false)

static func _ints(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in value:
			out[key] = _ints(value[key])
		return out
	if value is Array:
		return value.map(func(item: Variant) -> Variant: return _ints(item))
	if value is float and is_finite(value) and value == floorf(value):
		return int(value)
	return value

## An interchange with its stops, read the way the game reads them (without loading the network).
static func read_interchange(record: Dictionary) -> InterchangeData:
	var interchange: InterchangeData = InterchangeMapper.interchange_from_dict(record)
	for stop_record: Dictionary in record["stops"]:
		interchange.stops.append(StopMapper.stop_from_dict(stop_record))
	return interchange

func test_real_maps_round_trip() -> bool:
	for key: String in MAPS:
		var records: Array = JSON.parse_string(FileAccess.get_file_as_string("res://world/%s/jsondata/interchanges.json" % key))
		check(not records.is_empty(), "The %s catalog has interchanges to compare" % key)
		for record: Dictionary in records:
			var written: Dictionary = InterchangeMapper.interchange_to_dict(read_interchange(record))
			## Tool-only fields are not the mapper's: the editor addon writes them itself.
			var expected: Dictionary = record.duplicate(true)
			expected.erase("editorPosition")
			check(text(written) == text(expected), "%s interchange %d comes back unchanged:\n%s\n%s" % [key, int(record.num), text(written), text(expected)])
	return true

func test_all_fields() -> bool:
	## Everything a rail stop can say, in file order: a goods platform on the left, 12.5 m past node 3.
	var rail: Dictionary = {"num": 5, "domain": "RAIL", "trackNum": 9, "nodeIndex": 3, "nodeOffset": 12.5,
		"type": "STATION_GOODS", "hideBuilding": true, "platformSide": "LEFT"}
	var rail_stop: RailStationData = StopMapper.rail_stop_from_dict(rail)
	check(rail_stop.num == 5 and rail_stop.track_num == 9 and rail_stop.anchor.same_place(LineAnchor.new(3, 12.5)) \
		and rail_stop.station_type == "STATION_GOODS" and rail_stop.hide_building \
		and rail_stop.platform_side == RailStationData.PlatformSide.LEFT, "Every rail field is read")
	check(text(StopMapper.stop_to_dict(rail_stop)) == text(rail), "Every rail field is written back, in order")
	var road: Dictionary = {"num": 6, "domain": "ROAD", "roadNum": 2, "nodeIndex": 1, "nodeOffset": -4.25,
		"type": "BUS_STOP", "roadStopDirection": "ROAD_NODES_DECREASE", "hideBuilding": true}
	var road_stop: RoadStationData = StopMapper.road_stop_from_dict(road)
	check(road_stop.road_num == 2 and road_stop.anchor.same_place(LineAnchor.new(1, -4.25)) \
		and road_stop.direction == Enums.RoadStopDirection.ROAD_NODES_DECREASE and road_stop.station_type == "BUS_STOP",
		"Every road field is read")
	check(text(StopMapper.stop_to_dict(road_stop)) == text(road), "Every road field is written back, in order")
	check(StopMapper.stop_from_dict(road) is RoadStationData and StopMapper.stop_from_dict(rail) is RailStationData,
		"The domain picks the stop class")

	## A whole interchange: its own fields, then its stops in their order.
	var interchange: Dictionary = {"num": 4, "name": "Hafen", "townNum": 2, "townName": "Stadt", "stops": [rail, road]}
	check(text(InterchangeMapper.interchange_to_dict(read_interchange(interchange))) == text(interchange),
		"An interchange with stops of both domains comes back unchanged")
	return true

func test_defaults() -> bool:
	## Optional fields: defaults when missing, and not written while they keep the default.
	var rail_stop: RailStationData = StopMapper.rail_stop_from_dict({"num": 1, "trackNum": 2, "nodeIndex": 0})
	check(rail_stop.station_type == StopMapper.DEFAULT_RAIL_TYPE and not rail_stop.hide_building \
		and rail_stop.platform_side == RailStationData.PlatformSide.RIGHT and rail_stop.anchor.offset == 0.0,
		"A minimal rail record is a passenger platform on the right, on its node")
	check(text(StopMapper.stop_to_dict(rail_stop)) == text({"num": 1, "domain": "RAIL", "trackNum": 2, "nodeIndex": 0, "type": "STATION_PASS"}),
		"Rail stops always write their type, but no default side, building flag or offset")
	var road_stop: RoadStationData = StopMapper.road_stop_from_dict({"num": 3, "roadNum": 4, "nodeIndex": 2, "roadStopDirection": "BOTH_DIRECTIONS"})
	check(text(StopMapper.stop_to_dict(road_stop)) == text({"num": 3, "domain": "ROAD", "roadNum": 4, "nodeIndex": 2, "roadStopDirection": "BOTH_DIRECTIONS"}),
		"Road stops without a type write none")
	## Stops built in game have their name and town on the interchange; neither is written on the stop.
	var named := RailStationData.new(8, "Name", 3)
	named.track_num = 1
	check(not StopMapper.stop_to_dict(named).has("name") and not StopMapper.stop_to_dict(named).has("townNum"),
		"Name and town belong to the interchange record")
	var town_less: Dictionary = InterchangeMapper.interchange_to_dict(InterchangeMapper.interchange_from_dict(
		{"num": 1, "name": "Halt", "townNum": 0, "stops": []}))
	check(not town_less.has("townName") and town_less.townNum == 0, "An empty town name is left out")
	return true

func test_validation() -> bool:
	print("Checking invalid stop records; the following validation errors are expected.")
	var rail: Dictionary = {"num": 1, "domain": "RAIL", "trackNum": 2, "nodeIndex": 0}
	check(StopMapper.validation_error(rail).is_empty(), "A minimal rail record is valid")
	for fields: Dictionary in [{"platformSide": "left"}, {"platformSide": 1}, {"platformSide": "UP"}, {"domain": "WATER"},
			{"trackNum": -1}, {"nodeOffset": "2"}, {"type": 3}, {"hideBuilding": 1}]:
		var invalid: Dictionary = rail.duplicate()
		invalid.merge(fields, true)
		check(not StopMapper.validation_error(invalid).is_empty() and StopMapper.stop_from_dict(invalid) == null,
			"Invalid rail record is rejected: %s" % str(fields))
	check(StopMapper.road_stop_from_dict(rail) == null, "A record that says RAIL is not read as a road stop")
	var without_domain: Dictionary = rail.duplicate()
	without_domain.erase("domain")
	check(not StopMapper.validation_error(without_domain).is_empty() and StopMapper.rail_stop_from_dict(without_domain) != null,
		"Catalog records must name their domain; the typed readers imply it")
	for bad: Variant in [null, [], {"num": 1, "name": "", "townNum": 1, "stops": []}, {"num": 1, "name": "A", "townNum": 1},
			{"num": 1, "name": "A", "townNum": 1, "townName": 4, "stops": []}]:
		check(not InterchangeMapper.validation_error(bad).is_empty(), "Invalid interchange record is rejected: %s" % str(bad))
	return true

## The catalog validation uses the mappers' rules, so the new platformSide field passes it too.
func test_catalog_accepts() -> bool:
	var catalog: Array = [{"num": 1, "name": "Halt", "townNum": 1, "stops": [
		{"num": 1, "domain": "RAIL", "trackNum": 2, "nodeIndex": 0, "platformSide": "LEFT"}]}]
	check(InterchangesLoader.validate_definitions(catalog) == OK, "A catalog with a left platform is valid")
	catalog[0].stops[0].platformSide = "UP"
	print("Checking an invalid platform side; the following validation error is expected.")
	check(InterchangesLoader.validate_definitions(catalog) != OK, "An unknown platform side makes the catalog invalid")
	return true
