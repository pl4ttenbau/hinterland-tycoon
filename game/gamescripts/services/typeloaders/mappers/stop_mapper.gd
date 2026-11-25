@tool
## Stop records of interchanges.json <-> stop Resources (RailStationData, RoadStationData), both ways.
##
## Owns the format of a single stop record: which fields exist, their types, their defaults, and the key
## order they are written in (the order of the existing map files, so exported records match them).
## Checks that need more than one record (duplicate numbers, two platforms in one place) or the loaded
## network (does the track or road exist?) stay in InterchangesLoader and the stop loaders.
##
## A record, rail:  {"num", "domain": "RAIL", "trackNum", "nodeIndex", ["nodeOffset"], "type",
##                   ["hideBuilding": true], ["platformSide": "LEFT"]}
## A record, road:  {"num", "domain": "ROAD", "roadNum", "nodeIndex", ["nodeOffset"], ["type"],
##                   "roadStopDirection", ["hideBuilding": true]}
## Optional fields are only written when they differ from the default, like the hand-written files.
class_name StopMapper extends RefCounted

## Rail stops without a "type" are passenger stations; rail records always write it.
const DEFAULT_RAIL_TYPE: String = "STATION_PASS"
const DOMAINS: Array[String] = ["RAIL", "ROAD"]

#region Reading
## The stop for a record of either domain, or null (with the reason pushed as an error).
static func stop_from_dict(data: Dictionary) -> AbstractStation:
	if data.get("domain") == "ROAD":
		return road_stop_from_dict(data)
	return rail_stop_from_dict(data)

## A rail stop. "domain" may be left out (it is implied), but must say RAIL when present.
static func rail_stop_from_dict(data: Dictionary) -> RailStationData:
	var problem: String = validation_error(data, "RAIL")
	if not problem.is_empty():
		push_error(problem)
		return null
	var stop := RailStationData.new(int(data["num"]), data.get("name", ""), int(data.get("townNum", -1)))
	stop.track_num = int(data["trackNum"])
	stop.anchor = LineAnchor.from_dict(data)
	stop.platform_side = RailStationData.PlatformSide[data.get("platformSide", "RIGHT")]
	_read_shared(stop, data, DEFAULT_RAIL_TYPE)
	return stop

## A road stop. "domain" may be left out (it is implied), but must say ROAD when present.
static func road_stop_from_dict(data: Dictionary) -> RoadStationData:
	var problem: String = validation_error(data, "ROAD")
	if not problem.is_empty():
		push_error(problem)
		return null
	var stop := RoadStationData.new(int(data["num"]), data.get("name", ""), int(data.get("townNum", -1)))
	stop.road_num = int(data["roadNum"])
	stop.anchor = LineAnchor.from_dict(data)
	stop.direction = Enums.RoadStopDirection[data["roadStopDirection"]]
	_read_shared(stop, data, "")
	return stop

## Fields both domains have. Name and town normally come from the interchange after registration;
## standalone records (tests, older tools) may carry their own.
static func _read_shared(stop: AbstractStation, data: Dictionary, default_type: String) -> void:
	stop.town_name = data.get("townName", "")
	stop.station_type = data.get("type", default_type)
	stop.hide_building = data.get("hideBuilding", false)
#endregion

#region Writing
## The record for a stop, in the field order of the map files. Only what the stop itself owns: name and
## town belong to its interchange (InterchangeMapper writes those), and so does the nesting.
static func stop_to_dict(stop: AbstractStation) -> Dictionary:
	var rail: RailStationData = stop as RailStationData
	var road: RoadStationData = stop as RoadStationData
	var record: Dictionary = {"num": stop.num, "domain": "RAIL" if rail != null else "ROAD"}
	if rail != null:
		record["trackNum"] = rail.track_num
		rail.anchor.write_to(record)
		record["type"] = rail.station_type if not rail.station_type.is_empty() else DEFAULT_RAIL_TYPE
	else:
		record["roadNum"] = road.road_num
		road.anchor.write_to(record)
		if not road.station_type.is_empty():
			record["type"] = road.station_type
		record["roadStopDirection"] = Enums.RoadStopDirection.find_key(road.direction)
	if stop.hide_building:
		record["hideBuilding"] = true
	if rail != null and rail.platform_side != RailStationData.PlatformSide.RIGHT:
		record["platformSide"] = RailStationData.PlatformSide.find_key(rail.platform_side)
	return record
#endregion

#region Validation
## Why `data` is not a valid stop record, or "" when it is. `domain` ("RAIL"/"ROAD") is the expected
## domain; empty takes it from the record, which must then name one.
static func validation_error(data: Variant, domain: String = "") -> String:
	if not data is Dictionary or not InterchangeData.is_valid_num(data.get("num")):
		return "Stop requires a nonnegative integer num"
	var num: int = int(data["num"])
	if domain.is_empty():
		domain = str(data.get("domain", ""))
	if domain not in DOMAINS or (data.has("domain") and data["domain"] != domain):
		return "Stop %d requires domain RAIL or ROAD%s" % [num, "" if domain.is_empty() else " (expected %s)" % domain]
	var key: String = line_key(domain)
	if not InterchangeData.is_valid_num(data.get(key)):
		return "Stop %d requires a nonnegative integer %s" % [num, key]
	if LineAnchor.from_dict(data) == null:
		return "Stop %d requires a nonnegative integer nodeIndex and an optional numeric nodeOffset" % num
	for field: String in ["name", "townName", "type"]:
		if data.has(field) and not data[field] is String:
			return "Stop %d %s must be a string" % [num, field]
	if data.has("townNum") and not InterchangeData.is_valid_num(data["townNum"]):
		return "Stop %d townNum must be a nonnegative integer" % num
	if data.has("hideBuilding") and not data["hideBuilding"] is bool:
		return "Stop %d hideBuilding must be a boolean" % num
	if domain == "RAIL":
		if data.has("platformSide") and not (data["platformSide"] is String and RailStationData.PlatformSide.has(data["platformSide"])):
			return "Rail stop %d platformSide must be RIGHT or LEFT" % num
	elif not (data.get("roadStopDirection") is String and Enums.RoadStopDirection.has(data["roadStopDirection"])):
		return "Road stop %d requires roadStopDirection ROAD_NODES_INCREASE, ROAD_NODES_DECREASE or BOTH_DIRECTIONS" % num
	return ""

## The record field naming the stop's line: "trackNum" (RAIL) or "roadNum" (ROAD).
static func line_key(domain: String) -> String:
	return "trackNum" if domain == "RAIL" else "roadNum"
#endregion
