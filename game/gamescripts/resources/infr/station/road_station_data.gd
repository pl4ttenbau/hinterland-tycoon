@icon("res://assets/icons/icon_station_white.png")
class_name RoadStationData extends AbstractStation

@export var connected_town: TownData

## The stopping point is an authored road node, independent of building access links.
@export var road_num: int = -1
@export var node_index: int = -1
@export var direction: Enums.RoadStopDirection = Enums.RoadStopDirection.ROAD_NODES_INCREASE

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

func anchor(roads: RoadStore) -> RoadNode:
	var road: RoadData = roads._by_id.get(road_num)
	if road == null:
		return null
	var offset: float = curve_offset
	if offset < 0.0:
		if node_index < 0 or node_index >= road.nodes.size():
			return null
		var node: RoadNode = road.nodes[node_index]
		if direction == Enums.RoadStopDirection.BOTH_DIRECTIONS:
			return node
		if road.curve == null:
			road.build_curve()
		offset = RoadRouteAnchor.offset_of(node)
	if road.curve == null or offset > road.curve.get_baked_length():
		return null
	var result := RoadRouteAnchor.at(road, offset)
	match direction:
		Enums.RoadStopDirection.ROAD_NODES_INCREASE:
			result.arrival_direction = 1
		Enums.RoadStopDirection.ROAD_NODES_DECREASE:
			result.arrival_direction = -1
	return result

static func direction_key(data: Dictionary) -> String:
	var key: Variant = data.get("roadStopDirection")
	return key if key is String and Enums.RoadStopDirection.has(key) else ""

## Map JSON uses the same camelCase convention as rail station catalogs.
## Resolving road/node references and deriving world placement belong to the loader.
static func of_dict(data: Dictionary) -> RoadStationData:
	for field: String in ["num", "roadNum", "nodeIndex"]:
		if not _is_nonnegative_integer(data.get(field)):
			push_error("Road stop requires a nonnegative integer %s" % field)
			return null
	var served_direction: String = direction_key(data)
	if served_direction.is_empty():
		push_error("Road stop requires roadStopDirection ROAD_NODES_INCREASE, ROAD_NODES_DECREASE or BOTH_DIRECTIONS")
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
	station_obj.direction = Enums.RoadStopDirection[served_direction]
	station_obj.town_name = data.get("townName", "")
	station_obj.station_type = data.get("type", "")
	station_obj.hide_building = data.get("hideBuilding", false)
	return station_obj

static func _is_nonnegative_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) \
		and is_finite(float(value)) and value >= 0 and value == int(value)
