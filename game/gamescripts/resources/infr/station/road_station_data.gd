@icon("res://assets/icons/icon_station_white.png")
class_name RoadStationData extends AbstractStation

## The stopping point: a road, and where on it (node + offset, see LineAnchor), independent of
## building access links. Like rail stops since 2026-11-23.
@export var road_num: int = -1
@export var anchor: LineAnchor = LineAnchor.new()
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

## Where vehicles route to. A two-way stop exactly on its node can use the node itself (routing has no
## direction to enforce there); every other stop gets a temporary RoadRouteAnchor at its curve distance.
func route_anchor(roads: RoadStore) -> RoadNode:
	var road: RoadData = roads._by_id.get(road_num)
	if road == null or not self.anchor.is_valid_on(road):
		return null
	if direction == Enums.RoadStopDirection.BOTH_DIRECTIONS and self.anchor.offset == 0.0:
		return road.nodes[self.anchor.node_index]
	var result := RoadRouteAnchor.at(road, self.anchor.curve_offset(road))
	match direction:
		Enums.RoadStopDirection.ROAD_NODES_INCREASE:
			result.arrival_direction = 1
		Enums.RoadStopDirection.ROAD_NODES_DECREASE:
			result.arrival_direction = -1
	return result

