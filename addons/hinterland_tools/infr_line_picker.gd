@tool
extends RefCounted

const HIT_RADIUS_PIXELS: float = 10.0

## Return the authoring line, not one of its generated mesh/marker children.
func get_hits(world: Node, camera: Camera3D, mouse: Vector2, context: Dictionary) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	var query: Dictionary = {
		"camera": camera, "mouse": mouse, "inverse": camera.global_transform.affine_inverse(),
		"origin": camera.project_ray_origin(mouse), "direction": camera.project_ray_normal(mouse),
		"max_depth": context.get("max_depth", INF)
	}
	for node: Node in world.find_children("*", "", true, false):
		if not _is_pickable_line(node):
			continue
		var hit: Dictionary = _pick_line(node, query)
		if not hit.is_empty():
			hits.append(hit)
	return hits

func _is_pickable_line(node: Node) -> bool:
	return node is EditorInfrLine3D and node.is_visible_in_tree() and node.curve != null and node.curve.point_count >= 2

func _pick_line(line: EditorInfrLine3D, query: Dictionary) -> Dictionary:
	var samples: PackedVector3Array = line.curve.get_baked_points()
	var best: Dictionary = {}
	for idx: int in range(1, samples.size()):
		var hit: Dictionary = _pick_segment(line.to_global(samples[idx - 1]), line.to_global(samples[idx]), query)
		if not hit.is_empty() and (best.is_empty() or hit.screen_distance < best.screen_distance):
			best = hit
	if not best.is_empty():
		best["target"] = line
		best["label"] = "%s · ID %d · %s" % ["Road" if line.infr_domain == Enums.InfrDomain.ROAD else "Rail", line.num, line.infr_name]
	return best

func _pick_segment(a: Vector3, b: Vector3, query: Dictionary) -> Dictionary:
	var camera: Camera3D = query.camera
	# Behind-camera points project to mirrored screen positions, so clip first.
	var clipped: PackedVector3Array = clip_segment(a, b, query.inverse, camera.near, camera.far)
	if clipped.is_empty():
		return {}
	a = clipped[0]
	b = clipped[1]
	var screen_a: Vector2 = camera.unproject_position(a)
	var screen_b: Vector2 = camera.unproject_position(b)
	var mouse: Vector2 = query.mouse
	var delta: Vector2 = screen_b - screen_a
	var weight: float = clampf((mouse - screen_a).dot(delta) / delta.length_squared(), 0.0, 1.0) if delta.length_squared() > 0.000001 else 0.0
	var distance: float = mouse.distance_to(screen_a.lerp(screen_b, weight))
	if distance > HIT_RADIUS_PIXELS:
		return {}
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		var za: float = -(query.inverse * a).z
		var zb: float = -(query.inverse * b).z
		# Screen interpolation is nonlinear in world space under perspective.
		weight = weight * za / ((1.0 - weight) * zb + weight * za)
	var position: Vector3 = a.lerp(b, weight)
	var depth: float = (position - query.origin).dot(query.direction)
	if depth < 0.0 or depth > float(query.max_depth) + 0.3:
		return {}
	return {"world_position": position, "depth": depth, "screen_distance": distance}

static func clip_segment(a: Vector3, b: Vector3, inverse: Transform3D, near: float, far: float) -> PackedVector3Array:
	var za: float = -(inverse * a).z
	var zb: float = -(inverse * b).z
	var low: float = 0.0
	var high: float = 1.0
	if is_equal_approx(za, zb):
		if za < near or za > far:
			return []
	else:
		var first: float = (near - za) / (zb - za)
		var last: float = (far - za) / (zb - za)
		low = maxf(low, minf(first, last))
		high = minf(high, maxf(first, last))
	if low > high:
		return []
	return PackedVector3Array([a.lerp(b, low), a.lerp(b, high)])
