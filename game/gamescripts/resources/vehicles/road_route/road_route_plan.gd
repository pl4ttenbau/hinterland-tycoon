## An itinerary owns visits and transfer instructions; execution progress is separate.
class_name RoadRoutePlan extends Resource

@export var points: Array[RoadRoutePoint] = []
## After the final visit, navigate back to the first and repeat its actions.
@export var repeat_route: bool = false

## Legacy plans identify some visits by their road and authored node index.
func references_road_nodes(road_num: int) -> bool:
	for point: RoadRoutePoint in points:
		if point != null and point.kind == RoadRoutePoint.Kind.NODE and point.road_num == road_num:
			return true
	return false


## Return a reviewable error without modifying either the plan or its inventories.
func validate(network: RoadPathfinder, roads: RoadStore, stops: Dictionary, depots: Array[RoadDepotData], goods: Dictionary, capacity: GoodsCapacity, markers: RoadMarkerStore = null) -> String:
	if points.size() < 2:
		return "Add at least two route points."
	var previous: RoadNode
	var first: RoadNode
	for index: int in range(points.size()):
		var point: RoadRoutePoint = points[index]
		if point == null:
			return "Point %d is missing." % (index + 1)
		var node: RoadNode = point.resolve(roads, stops, depots, markers)
		if node == null:
			return "Point %d has an invalid road anchor." % (index + 1)
		if index == 0:
			first = node
		if previous != null and network.find_path(previous, node).is_empty():
			return "No road path from point %d to point %d." % [index, index + 1]
		var error: String = _validate_actions(point, stops, goods, capacity)
		if not error.is_empty():
			return "Point %d: %s" % [index + 1, error]
		previous = node
	if repeat_route and network.find_path(previous, first).is_empty():
		return "No road path from point %d back to point 1." % points.size()
	return ""

## Only physical stops have inventories today. Nodes/depots remain navigation points.
func _validate_actions(point: RoadRoutePoint, stops: Dictionary, goods: Dictionary, capacity: GoodsCapacity) -> String:
	if not point.actions.is_empty() and point.kind != RoadRoutePoint.Kind.STOP:
		return "Load/unload actions require a stop."
	for action: RoadRouteAction in point.actions:
		if action == null:
			return "Missing transfer action."
		var error: String = action.validate(goods, stops, capacity)
		if not error.is_empty():
			return error
	return ""
