@tool
## Stop anchors (LineAnchor: nodeIndex + nodeOffset) resolved against track/road JSON records in the editor.
##
## The editor works on raw JSON records, but an anchor's offset is a distance along the line's curve,
## which depends on how the game builds that curve (handles, auto smoothing). So every record is turned
## into a real RailTrackData/RoadData through the game's own mappers (side-effect free, @tool), and the
## anchor is resolved on that: the editor and the game always agree on where a stop is.
class_name EditorStopAnchors extends RefCounted

## The game line for one JSON record of the given domain ("RAIL"/"ROAD"), or null for too few points.
static func line_from_record(domain_key: String, record: Dictionary) -> AbstractInfrLine:
	if not record.get("points") is Array or record.points.size() < 2:
		return null
	# Geometry only: the curve depends on nothing else, and point metadata such as forks would make the
	# mapper build fork arms that hold their node strongly (a cycle that leaks at shutdown).
	var geometry: Dictionary = {"num": record.get("num", -1), "type": record.get("type", ""), "points": []}
	if record.has("autosmooth"):
		geometry["autosmooth"] = record.autosmooth
	for point: Dictionary in record.points:
		var copy: Dictionary = {}
		for key: String in ["pos", "handleIn", "handleOut"]:
			if point.has(key):
				copy[key] = point[key]
		geometry.points.append(copy)
	var line: AbstractInfrLine = RailMapper.rail_track_from_dict(geometry) if domain_key == "RAIL" \
		else RoadMapper.road_from_data_json(geometry)
	line.build_curve()
	return line

## Lines by number, built on first use: {"RAIL": {num: AbstractInfrLine}, "ROAD": {...}}.
## `records` is {"RAIL": {num: record}, "ROAD": {num: record}}.
class LineCache extends RefCounted:
	var records: Dictionary
	var _lines: Dictionary = {"RAIL": {}, "ROAD": {}}

	func _init(_records: Dictionary) -> void:
		self.records = _records

	func get_line(domain_key: String, num: int) -> AbstractInfrLine:
		var built: Dictionary = self._lines[domain_key]
		if not built.has(num):
			var record: Dictionary = self.records.get(domain_key, {}).get(num, {})
			built[num] = EditorStopAnchors.line_from_record(domain_key, record) if not record.is_empty() else null
		return built[num]

## World position of a stop record, or Vector3.INF when its line, node or anchor is invalid.
static func stop_position(stop: Dictionary, lines: LineCache) -> Vector3:
	var place: LineAnchor = LineAnchor.from_dict(stop)
	var line: AbstractInfrLine = lines.get_line(stop.domain, int(stop.get(_line_key(stop.domain), -1)))
	if place == null or line == null or not place.is_valid_on(line):
		return Vector3.INF
	return place.position_on(line)

## Re-anchor the stops on lines whose point count changed between `old_records` and `new_records`
## ({num: record} of one domain). Node indices after an inserted or removed point would name another
## node, so each stop is moved back to where it stood: its old position, projected onto the new curve.
## Stops on lines with an unchanged point count keep their anchor (node + offset follows the geometry).
## Changes `interchanges` (the interchanges.json records) in place; returns one line per moved anchor.
static func reanchor_stops(interchanges: Array, domain_key: String, old_records: Dictionary, new_records: Dictionary) -> Array[String]:
	var report: Array[String] = []
	var key: String = _line_key(domain_key)
	for interchange: Dictionary in interchanges:
		for stop: Dictionary in interchange.get("stops", []):
			if stop.get("domain") != domain_key:
				continue
			var num: int = int(stop.get(key, -1))
			var old_record: Dictionary = old_records.get(num, {})
			var new_record: Dictionary = new_records.get(num, {})
			if old_record.is_empty() or new_record.is_empty() or old_record.points.size() == new_record.points.size():
				continue
			var old_line: AbstractInfrLine = line_from_record(domain_key, old_record)
			var new_line: AbstractInfrLine = line_from_record(domain_key, new_record)
			var place: LineAnchor = LineAnchor.from_dict(stop)
			if old_line == null or new_line == null or place == null or not place.is_valid_on(old_line):
				continue
			var position: Vector3 = place.position_on(old_line)
			var moved: LineAnchor = LineAnchor.at_curve_offset(new_line, new_line.ensure_curve().get_closest_offset(position))
			if moved.same_place(place):
				continue
			moved.write_to(stop)
			report.append("Stop %d on %s %d: %s -> %s" % [int(stop.num), InfrDomains.singular(
				Enums.InfrDomain.RAIL if domain_key == "RAIL" else Enums.InfrDomain.ROAD), num, place, moved])
	return report

static func _line_key(domain_key: String) -> String:
	return "trackNum" if domain_key == "RAIL" else "roadNum"
