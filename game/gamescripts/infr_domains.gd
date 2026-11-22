@tool
## What differs between rail and road infrastructure by name only: files, labels, default types, editor
## colours and materials, node names. One table instead of `x if domain == ROAD else y` switches spread
## over the editor tools, as groundwork for unifying the rail and road code.
##
## Use as `InfrDomains.json_stem(domain)` etc. Only descriptive data belongs here; real behaviour that
## differs (crossings for roads, gauge handling for rails, ...) stays in the code that does it.
## Water and air have no infrastructure tools yet; asking for them is a programming error and returns
## empty values (with an error), never rail or road data by accident.
class_name InfrDomains extends RefCounted

## Per-domain values. Keys:
## json_stem: file name of the map's catalog, world/<map>/jsondata/<json_stem>.json
## key: the domain as written in JSON and metadata ("ROAD"/"RAIL"), equal to its Enums.InfrDomain name
## singular / plural / title: wording for messages, history entries and labels
## default_type: record "type" when a new line has none (road type key or rail gauge)
## stop_id_key: field naming the line a stop is anchored to, in interchanges.json ("trackNum"/"roadNum")
## node_prefix: node name of a line, followed by "_<num>" (RoadWay_12, RailTrack_7), matching runtime nodes
## editor_color: colour of an EditorInfrLine3D
## preview_color: colour of the line being drawn, brighter so it stands out from saved lines
## line_material: material of an EditorInfrLine3D
const RAIL: Dictionary = {
	"json_stem": "tracks",
	"key": "RAIL",
	"singular": "rail",
	"plural": "rails",
	"title": "Rail",
	"default_type": "NORMAL_GAUGE",
	"stop_id_key": "trackNum",
	"node_prefix": "RailTrack",
	"editor_color": Color.BLACK,
	"preview_color": Color.CYAN,
	"line_material": "res://assets/packed/materials/line3d_rail_track_mat.tres",
}
const ROAD: Dictionary = {
	"json_stem": "roads",
	"key": "ROAD",
	"singular": "road",
	"plural": "roads",
	"title": "Road",
	"default_type": "rural_road",
	"stop_id_key": "roadNum",
	"node_prefix": "RoadWay",
	"editor_color": Color.DARK_ORANGE,
	"preview_color": Color.ORANGE,
	"line_material": "res://assets/packed/materials/line3d_roadway_mat.tres",
}

#region Lookups
static func json_stem(domain: GameEnums.InfrDomain) -> String:
	return _row(domain).get("json_stem", "")

static func key(domain: GameEnums.InfrDomain) -> String:
	return _row(domain).get("key", "")

static func singular(domain: GameEnums.InfrDomain) -> String:
	return _row(domain).get("singular", "")

static func plural(domain: GameEnums.InfrDomain) -> String:
	return _row(domain).get("plural", "")

static func title(domain: GameEnums.InfrDomain) -> String:
	return _row(domain).get("title", "")

static func default_type(domain: GameEnums.InfrDomain) -> String:
	return _row(domain).get("default_type", "")

static func stop_id_key(domain: GameEnums.InfrDomain) -> String:
	return _row(domain).get("stop_id_key", "")

## Node name of line `num`, e.g. "RailTrack_7".
static func node_name(domain: GameEnums.InfrDomain, num: int) -> String:
	return "%s_%d" % [_row(domain).get("node_prefix", "Infr"), num]

static func editor_color(domain: GameEnums.InfrDomain) -> Color:
	return _row(domain).get("editor_color", Color.MAGENTA)

static func preview_color(domain: GameEnums.InfrDomain) -> Color:
	return _row(domain).get("preview_color", Color.MAGENTA)

static func line_material(domain: GameEnums.InfrDomain) -> ShaderMaterial:
	var path: String = _row(domain).get("line_material", "")
	return load(path) as ShaderMaterial if not path.is_empty() else null

## Whether `node` is the EditorObjects container holding this domain's reference lines.
static func is_reference_container(node: Node, domain: GameEnums.InfrDomain) -> bool:
	match domain:
		GameEnums.InfrDomain.RAIL:
			return node is GeneratedRailLines
		GameEnums.InfrDomain.ROAD:
			return node is GeneratedRoadWays
	return false
#endregion

static func _row(domain: GameEnums.InfrDomain) -> Dictionary:
	match domain:
		GameEnums.InfrDomain.RAIL:
			return RAIL
		GameEnums.InfrDomain.ROAD:
			return ROAD
	push_error("No infrastructure tools exist for domain %s." % GameEnums.InfrDomain.find_key(domain))
	return {}
