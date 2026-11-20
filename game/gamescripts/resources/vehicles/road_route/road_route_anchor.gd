## A temporary first/last-leg anchor, never inserted into a road's authored nodes.
class_name RoadRouteAnchor extends RoadNode

var curve_offset: float
## +1 increasing order, -1 decreasing, 0 either approach.
var arrival_direction: int = 0

static func at(road: RoadData, offset: float) -> RoadRouteAnchor:
	var anchor := RoadRouteAnchor.new()
	anchor.parent_track = road
	anchor.index = -1
	anchor.curve_offset = offset
	anchor.position = road.curve.sample_baked(offset)
	return anchor

func offset() -> float:
	return self.curve_offset
