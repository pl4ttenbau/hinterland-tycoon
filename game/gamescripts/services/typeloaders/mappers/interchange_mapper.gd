@tool
## Interchange records of interchanges.json <-> InterchangeData, both ways.
##
## A record: {"num", "name", "townNum", ["townName"], "stops": [stop records, see StopMapper]}.
## Reading builds the interchange alone: its stops need the loaded rails and roads, so the stop loaders
## create them later (InterchangesLoader keeps their records until then). Writing includes the stops.
## Fields only tools use (e.g. the editor's "editorPosition") are not read; a merge that writes into an
## existing file keeps them from the file itself.
class_name InterchangeMapper extends RefCounted

## The interchange for a record, without its stops, or null (with the reason pushed as an error).
static func interchange_from_dict(data: Dictionary) -> InterchangeData:
	var problem: String = validation_error(data)
	if not problem.is_empty():
		push_error(problem)
		return null
	var interchange := InterchangeData.new()
	interchange.num = int(data["num"])
	interchange.interchange_name = data["name"]
	interchange.town_num = int(data["townNum"])
	interchange.town_name = data.get("townName", "")
	return interchange

## The record for an interchange and all its stops, in the field order of the map files.
static func interchange_to_dict(interchange: InterchangeData) -> Dictionary:
	var record: Dictionary = {"num": interchange.num, "name": interchange.interchange_name, "townNum": interchange.town_num}
	if not interchange.town_name.is_empty():
		record["townName"] = interchange.town_name
	var stops: Array = []
	for stop: AbstractStation in interchange.stops:
		stops.append(StopMapper.stop_to_dict(stop))
	record["stops"] = stops
	return record

## Why `data` is not a valid interchange record, or "" when it is. Its stops are checked separately
## (StopMapper.validation_error), since the catalog checks them against each other as well.
static func validation_error(data: Variant) -> String:
	if not data is Dictionary or not InterchangeData.is_valid_num(data.get("num")) \
			or not data.get("name") is String or data["name"].strip_edges().is_empty() \
			or not InterchangeData.is_valid_num(data.get("townNum")) \
			or not data.get("townName", "") is String or not data.get("stops") is Array:
		return "Interchange requires num, name, townNum and a stops array"
	return ""
