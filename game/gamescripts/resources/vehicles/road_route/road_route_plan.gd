## An itinerary owns visits and transfer instructions; execution progress is separate.
class_name RoadRoutePlan extends Resource

@export var points: Array[RoadRoutePoint] = []

## Return a reviewable error without modifying either the plan or its inventories.
func validate(network: RoadPathfinder, roads: RoadStore, stops: Dictionary, depots: Array[RoadDepotData], goods: Dictionary, capacity: GoodsCapacity) -> String:
	if points.size() < 2:
		return "Add at least two route points."
	var previous: RoadNode
	for index: int in range(points.size()):
		var point: RoadRoutePoint = points[index]
		if point == null:
			return "Point %d is missing." % (index + 1)
		var node: RoadNode = point.resolve(roads, stops, depots)
		if node == null:
			return "Point %d has an invalid road anchor." % (index + 1)
		if previous != null and network.find_path(previous, node).is_empty():
			return "No road path from point %d to point %d." % [index, index + 1]
		var error: String = _validate_actions(point, stops, goods, capacity)
		if not error.is_empty():
			return "Point %d: %s" % [index + 1, error]
		previous = node
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
