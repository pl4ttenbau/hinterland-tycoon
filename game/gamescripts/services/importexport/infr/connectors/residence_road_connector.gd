@tool
class_name ResidenceRoadConnector extends RefCounted

const CONNECTION = preload("res://game/gamescripts/resources/structures/residential/road_connection.gd")
const MAX_DISTANCE: float = 50.0

## Callers supply the active editor roads, avoiding a dependency on editor caches.
static func find_on_editor_roads(exit_position: Vector3, roads: Array[EditorInfrLine3D], max_distance: float = MAX_DISTANCE) -> CONNECTION:
	var candidates: Array[Dictionary] = []
	for road: EditorInfrLine3D in roads:
		if is_instance_valid(road) and road.infr_domain == Enums.InfrDomain.ROAD:
			candidates.append({"num": road.num, "curve": road.curve, "transform": road.global_transform})
	return _find_nearest(exit_position, candidates, max_distance)

static func find_on_roads(exit_position: Vector3, roads: Array[RoadData], max_distance: float = MAX_DISTANCE) -> CONNECTION:
	var candidates: Array[Dictionary] = []
	for road: RoadData in roads:
		if road == null:
			continue
		if road.curve == null:
			road.build_curve()
		candidates.append({"num": road.num, "curve": road.curve, "transform": Transform3D(Basis.IDENTITY, road.start_pos)})
	return _find_nearest(exit_position, candidates, max_distance)

## Transform control points AND handles before measuring, so offsets remain metres
## even for rotated/scaled editor lines. Baked, linear sampling matches projection.
static func world_curve(curve: Curve3D, transform: Transform3D) -> Curve3D:
	var result := Curve3D.new()
	for index: int in range(curve.point_count):
		result.add_point(transform * curve.get_point_position(index),
			transform.basis * curve.get_point_in(index), transform.basis * curve.get_point_out(index))
	return result

static func _find_nearest(exit_position: Vector3, candidates: Array[Dictionary], max_distance: float) -> CONNECTION:
	if not exit_position.is_finite() or not is_finite(max_distance) or max_distance < 0:
		return null
	var nearest: CONNECTION
	var best_distance: float = max_distance * max_distance
	for candidate: Dictionary in candidates:
		var curve: Curve3D = candidate.curve
		if candidate.num < 0 or curve == null or curve.point_count < 2:
			continue
		var projected_curve: Curve3D = world_curve(curve, candidate.transform)
		if projected_curve.get_baked_length() <= 0:
			continue
		var closest: Vector3 = projected_curve.get_closest_point(exit_position)
		var distance: float = closest.distance_squared_to(exit_position)
		if distance > best_distance or (nearest != null and is_equal_approx(distance, best_distance) and candidate.num >= nearest.road_num):
			continue
		best_distance = distance
		nearest = CONNECTION.new()
		nearest.road_num = candidate.num
		nearest.dist_from_zero = projected_curve.get_closest_offset(exit_position)
	return nearest
