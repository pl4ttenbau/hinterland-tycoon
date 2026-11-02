## Temporary driving geometry in world metres, independent of vehicle physics.
## This executes an already chosen road sequence. Future node-to-node pathfinding,
## station destinations and itineraries with goods actions belong to other classes.
## Reverse the first road with backwards=true; subsequent roads orient to its exit.
class_name RoadVehicleRoute extends RefCounted

const JOIN_TOLERANCE: float = 0.1
const SAMPLE_SPACING: float = 0.75

## World-space samples consumed by steering; source roads keep their own curves.
var curve: Curve3D
## Vehicle-specific progress in metres, preserved while the player takes control.
var progress: float = 0.0
var _paths: Array[Path3D] = []

## Build partial-road segments in either direction, retaining live infrastructure references.
## Depot arrivals trim the end in world metres to stay outside the building.
func assign_segments(segments: Array[Dictionary], end_trim: float = 0.0) -> bool:
	var candidate := Curve3D.new()
	var paths: Array[Path3D] = []
	for segment: Dictionary in segments:
		var path: Path3D = segment.path
		if not _is_usable_path(path):
			return false
		var length: float = absf(float(segment.to) - float(segment.from))
		var count: int = maxi(1, ceili(length / SAMPLE_SPACING))
		for index: int in range(count + 1):
			var offset: float = lerpf(float(segment.from), float(segment.to), float(index) / count)
			var point: Vector3 = path.to_global(path.curve.sample_baked(offset))
			if candidate.point_count == 0 or candidate.get_point_position(candidate.point_count - 1).distance_to(point) > 0.001:
				candidate.add_point(point)
		paths.append(path)
	if candidate.point_count < 2 or candidate.get_baked_length() <= end_trim:
		return false
	if end_trim > 0.0:
		candidate = _trim_end(candidate, end_trim)
	curve = candidate
	_paths = paths
	progress = 0.0
	return true

func _trim_end(source: Curve3D, distance: float) -> Curve3D:
	var result := Curve3D.new()
	var length: float = source.get_baked_length() - distance
	var offset: float = 0.0
	while offset < length:
		result.add_point(source.sample_baked(offset))
		offset += SAMPLE_SPACING
	result.add_point(source.sample_baked(length))
	return result

## Validate into a temporary curve, committing only after every join succeeds.
func assign(paths: Array[Path3D], backwards: bool = false) -> bool:
	if paths.is_empty():
		return false
	var candidate := Curve3D.new()
	candidate.bake_interval = 0.25
	var last: Vector3
	for index: int in range(paths.size()):
		var path: Path3D = paths[index]
		if not _is_usable_path(path):
			return false
		var length: float = path.curve.get_baked_length()
		var start: Vector3 = path.to_global(path.curve.sample_baked(0.0))
		var end: Vector3 = path.to_global(path.curve.sample_baked(length))
		var reverse: bool = backwards if index == 0 else last.distance_to(end) < last.distance_to(start)
		if index > 0 and last.distance_to(end if reverse else start) > JOIN_TOLERANCE:
			return false
		_append_path_samples(candidate, path, reverse, index > 0)
		last = candidate.get_point_position(candidate.point_count - 1)
	curve = candidate
	_paths.assign(paths)
	progress = 0.0
	return true

func _is_usable_path(path: Path3D) -> bool:
	return is_instance_valid(path) and path.is_inside_tree() \
		and path.curve != null and path.curve.get_baked_length() >= 0.01

## Include parent scale in sample density so offsets on the resulting curve
## measure world metres. Skip the shared endpoint when appending a further road.
func _append_path_samples(candidate: Curve3D, path: Path3D, reverse: bool, skip_start: bool) -> void:
	var length: float = path.curve.get_baked_length()
	var scale: Vector3 = path.global_basis.get_scale().abs()
	var count: int = maxi(1, ceili(length * maxf(scale.x, maxf(scale.y, scale.z)) / SAMPLE_SPACING))
	for sample: int in range(1 if skip_start else 0, count + 1):
		var offset: float = length * float(sample) / float(count)
		candidate.add_point(path.to_global(path.curve.sample_baked(length - offset if reverse else offset)))

## Freed or detached infrastructure cannot supply a live driving path.
func is_valid() -> bool:
	if curve == null:
		return false
	for path: Path3D in _paths:
		if not is_instance_valid(path) or not path.is_inside_tree():
			return false
	return true

## Search near the saved progress, so intersecting routes cannot skip to a later segment.
func update_progress(world_position: Vector3, search_distance: float = 15.0) -> void:
	if not is_valid():
		return
	var first: float = maxf(0.0, progress - search_distance)
	var last: float = minf(curve.get_baked_length(), progress + search_distance)
	var closest: float = progress
	var best: float = INF
	var offset: float = first
	while offset <= last:
		var distance: float = world_position.distance_squared_to(curve.sample_baked(offset))
		if distance < best:
			best = distance
			closest = offset
		offset += 0.25
	progress = closest

func remaining() -> float:
	return maxf(0.0, curve.get_baked_length() - progress) if is_valid() else 0.0

func sample_ahead(distance: float) -> Vector3:
	return curve.sample_baked(minf(progress + distance, curve.get_baked_length()))
