@icon("res://assets/icons/icon_station_white.png")
class_name RoadStationData extends AbstractStation

@export var connected_town: TownData

## The stopping point is an authored road node, independent of building access links.
@export var road_num: int = -1
@export var node_index: int = -1
## Side relative to increasing node order; BOTH can describe a future two-sided stop.
@export var road_side: Enums.RoadSide = Enums.RoadSide.RIGHT
## Direction through the road's node order; STOP is not a served direction.
@export var direction: Enums.PathDirection = Enums.PathDirection.TRACK_NODES_INCREASE

## World position of the station representation, like RailStationData.position.
@export var position: Vector3:
	set(value):
		position = value
		self.positioned.emit(value)

func _init(_num: int = -1, _name: String = "", _town_num: int = -1) -> void:
	super()
	self.num = _num
	self.station_name = _name
	self.town_num = _town_num

## Map JSON uses the same camelCase convention as rail station catalogs.
## Resolving road/node references and deriving world placement belong to the loader.
static func of_dict(data: Dictionary) -> RoadStationData:
	for field: String in ["num", "roadNum", "nodeIndex"]:
		if not _is_nonnegative_integer(data.get(field)):
			push_error("Road stop requires a nonnegative integer %s" % field)
			return null
	if not data.get("roadSide") is String or not Enums.RoadSide.has(data["roadSide"]):
		push_error("Road stop requires roadSide LEFT, RIGHT or BOTH")
		return null
	for field: String in ["name", "townName", "type"]:
		if data.has(field) and not data[field] is String:
			push_error("Road stop %s must be a string" % field)
			return null
	if data.has("townNum") and not _is_nonnegative_integer(data["townNum"]):
		push_error("Road stop townNum must be a nonnegative integer")
		return null
	if data.has("hideBuilding") and not data["hideBuilding"] is bool:
		push_error("Road stop hideBuilding must be a boolean")
		return null
	var station_obj := RoadStationData.new(int(data["num"]), data.get("name", ""), int(data.get("townNum", -1)))
	station_obj.road_num = int(data["roadNum"])
	station_obj.node_index = int(data["nodeIndex"])
	station_obj.road_side = Enums.RoadSide[data["roadSide"]]
	station_obj.town_name = data.get("townName", "")
	station_obj.station_type = data.get("type", "")
	station_obj.hide_building = data.get("hideBuilding", false)
	return station_obj

static func _is_nonnegative_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) \
		and is_finite(float(value)) and value >= 0 and value == int(value)
