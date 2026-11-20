@icon("res://assets/icons/icon_rail_track_white.png")
class_name InfrUtils extends RefCounted

const MIN_SMOOTH_POINT_DISTANCE: float = 0.0001
const GROUND_CLEARANCE: float = 0.2

## Interpolate the existing points with centripetal Catmull-Rom, expressed as
## Curve3D's relative Bezier handles. Point positions (including snapped ends)
## never move. Recompute by default so moving/adding points can update a preview.
## Loaders opt into preserving authored handles; an explicit smoothing action does not.
static func smooth_curve3d(curve: Curve3D, preserve_existing_handles: bool = false) -> void:
	for idx: int in range(curve.point_count):
		if preserve_existing_handles and (curve.get_point_in(idx) != Vector3.ZERO or curve.get_point_out(idx) != Vector3.ZERO):
			continue
		var handles: PackedVector3Array = _catmull_rom_handles(curve, idx)
		curve.set_point_in(idx, handles[0])
		curve.set_point_out(idx, handles[1])

static func _catmull_rom_handles(curve: Curve3D, idx: int) -> PackedVector3Array:
	var last_idx: int = curve.point_count - 1
	if last_idx < 1:
		return PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	var point: Vector3 = curve.get_point_position(idx)
	# Reflect the neighboring point at each open end. Unlike repeating the end
	# point, this supplies a nonzero knot interval and a chord-aligned end tangent.
	if idx == 0:
		return PackedVector3Array([Vector3.ZERO, (curve.get_point_position(1) - point) / 3.0])
	if idx == last_idx:
		return PackedVector3Array([(curve.get_point_position(idx - 1) - point) / 3.0, Vector3.ZERO])
	var previous: Vector3 = curve.get_point_position(idx - 1)
	var following: Vector3 = curve.get_point_position(idx + 1)
	var previous_distance: float = previous.distance_to(point)
	var next_distance: float = point.distance_to(following)
	# Catmull-Rom is undefined at coincident consecutive points (zero knot span).
	# Use zero handles there, retaining every point without divisions by zero or loops.
	if previous_distance <= MIN_SMOOTH_POINT_DISTANCE or next_distance <= MIN_SMOOTH_POINT_DISTANCE:
		return PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	# Centripetal knots use distance^alpha, alpha = 1/2. These unequal spans
	# prevent a short segment from inheriting a long neighbor's handle length.
	var before: float = sqrt(previous_distance)
	var after: float = sqrt(next_distance)
	# Derivative with respect to the nonuniform knot parameter, using BOTH neighbors.
	# See https://www.cemyuksel.com/research/catmullrom_param/ for the construction.
	var tangent: Vector3 = (point - previous) / before \
		- (following - previous) / (before + after) + (following - point) / after
	# A cubic Bezier's endpoint derivative is three times its handle. Rescale
	# separately for each segment's [0, 1] parameter: in/out are collinear but
	# generally have different lengths when the point spacing is uneven.
	return PackedVector3Array([-tangent * before / 3.0, tangent * after / 3.0])

## Keep the horizontal road shape and apply the Catmull-Rom tangent's grade.
static func smooth_curve3d_y(curve: Curve3D) -> void:
	for idx: int in range(curve.point_count):
		var handles: PackedVector3Array = _catmull_rom_handles(curve, idx)
		curve.set_point_in(idx, _handle_with_grade(curve.get_point_in(idx), handles[0]))
		curve.set_point_out(idx, _handle_with_grade(curve.get_point_out(idx), handles[1]))

static func _handle_with_grade(handle: Vector3, reference: Vector3) -> Vector3:
	if handle == Vector3.ZERO:
		return handle
	var horizontal_length: float = Vector2(handle.x, handle.z).length()
	var reference_length: float = Vector2(reference.x, reference.z).length()
	# Copy the slope, not just the Y offset: the existing horizontal handle may
	# be much longer/shorter than the generated one. A collapsed handle stays zero.
	if reference_length > MIN_SMOOTH_POINT_DISTANCE:
		handle.y = reference.y * horizontal_length / reference_length
	else:
		handle.y = reference.y
	return handle
			
## Smallest axis-aligned box that contains every point, in the points' own space.
## Only the points are bounded: a curve's handles can bulge past this box.
## No points gives an empty box at the origin.
static func get_aabb(points: Array[Vector3]) -> AABB:
	if points.is_empty():
		return AABB()
	# Start as a zero-size box on the first point, so a point at the origin is
	# handled like any other (it is not a "not set yet" marker).
	var bounds := AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		# expand() grows every axis that the point lies outside of, not just one.
		bounds = bounds.expand(point)
	return bounds

static func infr_domain_str_2_enum(infr_domain_str: String) -> Enums.InfrDomain:
	if infr_domain_str == "RAIL": return Enums.InfrDomain.RAIL
	elif infr_domain_str == "ROAD": return Enums.InfrDomain.ROAD
	elif infr_domain_str == "WATER": return Enums.InfrDomain.WATER
	elif infr_domain_str == "AIR": return Enums.InfrDomain.AIR
	else: return Enums.InfrDomain.STATIONARY


## PathMesh3D requires at least one complete tile. Compress the source along
## the path for short sections, preserving their width, material and collision.
static func fit_short_path_mesh(path_mesh: PathMesh3D, curve: Curve3D) -> void:
	var source: Mesh = path_mesh.mesh
	if source == null or curve == null:
		return
	# The rail and road source tiles are aligned to local Z.
	var bounds: AABB = source.get_aabb()
	var tile_length: float = maxf(0.0, bounds.end.z) - minf(0.0, bounds.position.z)
	var section_length: float = curve.get_baked_length()
	if section_length <= 0.0 or section_length >= tile_length:
		return
	var scale_z: float = (section_length / tile_length) * 0.99999
	var transform := Transform3D(Basis.from_scale(Vector3(1.0, 1.0, scale_z)), Vector3.ZERO)
	var fitted := ArrayMesh.new()
	for index: int in source.get_surface_count():
		var surface := SurfaceTool.new()
		surface.append_from(source, index, transform)
		surface.set_material(source.surface_get_material(index))
		surface.commit(fitted)
	path_mesh.mesh = fitted
