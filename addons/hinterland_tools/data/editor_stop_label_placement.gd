@tool
## Validated identity and world position used to create one rail/road stop label.
class_name EditorStopLabelPlacement extends RefCounted

var stop_num: int
var interchange_num: int
var domain: Enums.InfrDomain
var node_index: int
var station_name: String
var position: Vector3

## JSON conversion and placement validation happen together at the boundary.
static func from_definition(stop: Dictionary, name: String, world_position: Vector3) -> EditorStopLabelPlacement:
	for field: String in ["num", "interchangeNum", "nodeIndex"]:
		if not InterchangeData.is_valid_num(stop.get(field)):
			return null
	if stop.get("domain") not in ["RAIL", "ROAD"] or name.strip_edges().is_empty() or not world_position.is_finite():
		return null
	var placement := EditorStopLabelPlacement.new()
	placement.stop_num = int(stop["num"])
	placement.interchange_num = int(stop["interchangeNum"])
	placement.node_index = int(stop["nodeIndex"])
	placement.domain = Enums.InfrDomain.RAIL if stop["domain"] == "RAIL" else Enums.InfrDomain.ROAD
	placement.station_name = name
	placement.position = world_position
	return placement
