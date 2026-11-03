## Temporary world-space manoeuvre geometry. The vehicle controller owns physics
## handoff and collision checks; this helper only builds and samples the curve.
class_name RoadVehicleUTurn extends RefCounted

var curve: Curve3D
var progress: float = 0
var active: bool = false
var source: Path3D
var _entry_basis: Basis

## Two joined cubic curves form a narrow teardrop at the road end. Entry/exit
## share a road position, with opposite headings; no real steering radius applies.
func build(pose: Transform3D, path: Path3D, endpoint: float, radius: float) -> bool:
	if not is_instance_valid(path) or not path.is_inside_tree() or path.curve == null or not is_finite(radius) or radius <= 0:
		return false
	var length: float = path.curve.get_baked_length()
	if length < 0.1 or (not is_zero_approx(endpoint) and not is_equal_approx(endpoint, length)):
		return false
	source = path
	_entry_basis = pose.basis.orthonormalized()
	var inward: float = 1.0 if endpoint < 0.1 else -1.0
	var ground_end: Vector3 = path.to_global(path.curve.sample_baked(endpoint))
	var inner: Vector3 = path.to_global(path.curve.sample_baked(clampf(endpoint + inward * 0.1, 0, length)))
	var outward: Vector3 = (ground_end - inner).normalized()
	var right: Vector3 = outward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.5:
		return false
	var metres_per_offset: float = ground_end.distance_to(inner) / 0.1
	var setback: float = maxf(0, (ground_end - pose.origin).dot(outward))
	var exit_offset: float = clampf(endpoint + inward * setback / maxf(0.001, metres_per_offset), 0, length)
	var ground_exit: Vector3 = path.to_global(path.curve.sample_baked(exit_offset))
	var exit: Vector3 = ground_exit + Vector3.UP * (pose.origin.y - ground_exit.y)
	var apex: Vector3 = ground_end + Vector3.UP * (pose.origin.y - ground_exit.y) + outward * radius + right * radius
	var reach: float = setback + radius
	curve = Curve3D.new()
	curve.bake_interval = 0.05
	curve.add_point(pose.origin, Vector3.ZERO, _entry_basis.z * reach)
	curve.add_point(apex, -right * radius, right * radius)
	curve.add_point(exit, outward * reach)
	progress = 0
	active = true
	return true

func is_valid() -> bool:
	return active and curve != null and is_instance_valid(source) and source.is_inside_tree()

func sample(offset: float) -> Transform3D:
	var length: float = curve.get_baked_length()
	var before: Vector3 = curve.sample_baked(maxf(0, offset - 0.05))
	var after: Vector3 = curve.sample_baked(minf(length, offset + 0.05))
	var heading: Basis = Basis.looking_at((after - before).normalized(), Vector3.UP, true)
	# Preserve the exact takeover pose, blending out suspension roll/pitch gently.
	heading = _entry_basis.slerp(heading, clampf(offset / 0.5, 0, 1))
	return Transform3D(heading, curve.sample_baked(offset))
