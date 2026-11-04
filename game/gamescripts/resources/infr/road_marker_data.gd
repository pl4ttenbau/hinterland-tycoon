## One logical waypoint; BOTH has two roadside signs but only one routing identity.
class_name RoadMarkerData extends Resource

@export var num: int
@export var marker_name: String
@export var road_num: int
## Local curve distance, independent of how many shape nodes the road contains.
@export var offset: float
@export var side: Enums.RoadSide = Enums.RoadSide.RIGHT

func anchor(roads: RoadStore) -> RoadRouteAnchor:
	var road: RoadData = roads._by_id.get(road_num)
	if road == null or road.curve == null or offset < 0 or offset > road.curve.get_baked_length():
		return null
	var result: RoadRouteAnchor = RoadRouteAnchor.at(road, offset)
	result.arrival_direction = 0 if side == Enums.RoadSide.BOTH else (1 if side == Enums.RoadSide.RIGHT else -1)
	return result
