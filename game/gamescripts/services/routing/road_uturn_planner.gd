## Identify reversals at road ends without changing authored roads or graph nodes.
class_name RoadUTurnPlanner extends RefCounted

class Approach extends RefCounted:
	var segments: Array[Dictionary] = []
	var path: Path3D
	var offset: float

## A target behind the car first sends it to the end in its current direction.
## Also split an itinerary at an internal reversal, such as serving a sided marker.
static func prepare(segments: Array[Dictionary], forward: Vector3) -> Approach:
	var previous: Dictionary = {}
	for index: int in range(segments.size()):
		var segment: Dictionary = segments[index]
		if absf(float(segment.to) - float(segment.from)) < 0.01:
			continue
		var direction: Vector3 = _direction(segment, false)
		if previous.is_empty() and forward.normalized().dot(direction) < -0.65:
			var result := Approach.new()
			result.path = segment.path
			result.offset = 0.0 if float(segment.to) > float(segment.from) else result.path.curve.get_baked_length()
			result.segments.append({"path": result.path, "from": segment.from, "to": result.offset})
			return result
		if not previous.is_empty() and _direction(previous, true).dot(direction) < -0.8:
			var result := Approach.new()
			result.path = previous.path
			result.offset = previous.to
			# An assisted reversal belongs only at an actual road endpoint.
			if not is_zero_approx(result.offset) and not is_equal_approx(result.offset, result.path.curve.get_baked_length()):
				return null
			for before: int in range(index):
				result.segments.append(segments[before])
			return result
		previous = segment
	return null

static func _direction(segment: Dictionary, at_end: bool) -> Vector3:
	var path: Path3D = segment.path
	var direction: float = signf(float(segment.to) - float(segment.from))
	var offset: float = float(segment.to) if at_end else float(segment.from)
	var inner: float = offset + direction * (-0.1 if at_end else 0.1)
	inner = clampf(inner, minf(segment.from, segment.to), maxf(segment.from, segment.to))
	var tangent: Vector3 = path.to_global(path.curve.sample_baked(inner)) - path.to_global(path.curve.sample_baked(offset))
	return (-tangent if at_end else tangent).normalized()
