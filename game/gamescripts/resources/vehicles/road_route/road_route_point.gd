## Stable map references, independent of rendered nodes and current scene paths.
class_name RoadRoutePoint extends Resource

## Keep old numeric kinds stable for existing plans; NODE is no longer offered by the UI.
enum Kind { NODE, STOP, DEPOT, MARKER }
@export var kind: Kind = Kind.NODE
@export var road_num: int = -1
@export var node_index: int = -1
@export var target_num: int = -1
@export var actions: Array[RoadRouteAction] = []

## Resolve fresh when validating; deleted or changed anchors must not silently retarget.
func resolve(roads: RoadStore, stops: Dictionary, depots: Array[RoadDepotData], markers: RoadMarkerStore = null) -> RoadNode:
	if kind == Kind.MARKER:
		var marker: RoadMarkerData = markers.get_by_num(target_num) if markers != null else null
		return marker.anchor(roads) if marker != null else null
	var road_id: int = road_num
	var index: int = node_index
	if kind == Kind.STOP:
		var stop: RoadStationData = stops.get(target_num) as RoadStationData
		if stop == null:
			return null
		road_id = stop.road_num
		index = stop.node_index
	elif kind == Kind.DEPOT:
		var depot: RoadDepotData = _find_depot(depots)
		if depot == null or depot.road_pos not in ["START", "END"]:
			return null
		road_id = depot.road_num
		var depot_road: RoadData = roads._by_id.get(road_id)
		if depot_road == null:
			return null
		index = 0 if depot.road_pos == "START" else depot_road.nodes.size() - 1
	elif kind != Kind.NODE:
		return null
	var road: RoadData = roads._by_id.get(road_id)
	return road.nodes[index] if road != null and index >= 0 and index < road.nodes.size() else null

func _find_depot(depots: Array[RoadDepotData]) -> RoadDepotData:
	for depot: RoadDepotData in depots:
		if depot.num == target_num:
			return depot
	return null

func describe() -> String:
	match kind:
		Kind.STOP: return "Stop %d" % target_num
		Kind.DEPOT: return "Depot %d" % target_num
		Kind.MARKER: return "Marker %d" % target_num
	return "Road %d / node %d" % [road_num, node_index]
