@tool
class_name ResidenceRoadConnector extends RefCounted

const MAX_DISTANCE: float = 50.0

static func door_for(house: Node3D) -> Node3D:
	for child: Node in house.find_children("*", "", true, false):
		if child is ResidenceDoor:
			return child
	return null

static func exit_for(house: Node3D) -> Vector3:
	var door: Node3D = door_for(house)
	return door.get_exit_position() if door != null else house.global_position

## Cached edits take precedence over source lines with the same persistent ID.
static func editor_roads(world: Node) -> Array[EditorInfrLine3D]:
	var by_id: Dictionary = {}
	var cache: Node = world.get_node_or_null("EditorCache")
	for node: Node in world.find_children("*", "", true, false):
		if node is EditorInfrLine3D and node.infr_domain == Enums.InfrDomain.ROAD and node.num >= 0:
			if not by_id.has(node.num) or (cache != null and cache.is_ancestor_of(node)):
				by_id[node.num] = node
	var result: Array[EditorInfrLine3D] = []
	result.assign(by_id.values())
	return result

## Callers supply the active editor roads, avoiding a dependency on editor caches.
static func find_on_editor_roads(exit_position: Vector3, roads: Array[EditorInfrLine3D], max_distance: float = MAX_DISTANCE) -> RoadConnection:
	return find_prepared(exit_position, prepare_editor_roads(roads), max_distance)

## Prepare once per batch, rather than rebuilding every road for every house.
static func prepare_editor_roads(roads: Array[EditorInfrLine3D]) -> Array[RoadCurveCandidate]:
	var candidates: Array[RoadCurveCandidate] = []
	for road: EditorInfrLine3D in roads:
		if is_instance_valid(road) and road.infr_domain == Enums.InfrDomain.ROAD and road.curve != null:
			candidates.append(RoadCurveCandidate.from_curve(road.num, road.curve, road.global_transform))
	return candidates

static func find_on_roads(exit_position: Vector3, roads: Array[RoadData], max_distance: float = MAX_DISTANCE) -> RoadConnection:
	return find_prepared(exit_position, prepare_roads(roads), max_distance)

static func prepare_roads(roads: Array[RoadData]) -> Array[RoadCurveCandidate]:
	var candidates: Array[RoadCurveCandidate] = []
	for road: RoadData in roads:
		if road == null:
			continue
		if road.curve == null:
			road.build_curve()
		candidates.append(RoadCurveCandidate.from_curve(road.num, road.curve, Transform3D(Basis.IDENTITY, road.start_pos)))
	return candidates

## Transform control points AND handles before measuring, so offsets remain metres
## even for rotated/scaled editor lines. Baked, linear sampling matches projection.
static func world_curve(curve: Curve3D, transform: Transform3D) -> Curve3D:
	return RoadCurveCandidate.from_curve(0, curve, transform).curve

static func find_prepared(exit_position: Vector3, candidates: Array[RoadCurveCandidate], max_distance: float = MAX_DISTANCE) -> RoadConnection:
	if not exit_position.is_finite() or not is_finite(max_distance) or max_distance < 0:
		return null
	var nearest: RoadConnection = null
	var best_distance: float = max_distance * max_distance
	for candidate: RoadCurveCandidate in candidates:
		var curve: Curve3D = candidate.curve
		if not candidate.is_valid():
			continue
		var projected_curve: Curve3D = curve
		if projected_curve.get_baked_length() <= 0:
			continue
		var closest: Vector3 = projected_curve.get_closest_point(exit_position)
		var distance: float = closest.distance_squared_to(exit_position)
		if distance > best_distance or (nearest != null and is_equal_approx(distance, best_distance) and candidate.num >= nearest.road_num):
			continue
		best_distance = distance
		nearest = RoadConnection.new()
		nearest.road_num = candidate.num
		nearest.dist_from_zero = projected_curve.get_closest_offset(exit_position)
	return nearest
