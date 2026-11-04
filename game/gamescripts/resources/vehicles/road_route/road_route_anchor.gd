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
	anchor.rel_position = road.curve.sample_baked(offset)
	anchor.position = road.start_pos + anchor.rel_position
	return anchor

static func offset_of(node: RoadNode) -> float:
	if node is RoadRouteAnchor:
		return node.curve_offset
	# Coincident start/end positions on a loop still represent different arc offsets.
	if node.index == 0:
		return 0.0
	if node.index == node.parent_track.nodes.size() - 1:
		return node.parent_track.curve.get_baked_length()
	return node.parent_track.curve.get_closest_offset(node.rel_position)
