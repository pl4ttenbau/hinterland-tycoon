@tool
extends RefCounted

const SNAP_PIXELS: float = 16.0
const RELEASE_PIXELS: float = 22.0
const SNAP_WORLD_DISTANCE: float = 30.0

var world: WorldMapScene
var domain: Enums.InfrDomain
var points: Array[Vector3] = []
var endpoints: Array[EditorInfrLine3D] = []
var candidate: EditorInfrLine3D
var candidate_index: int = -1
var placement: Vector3
var placement_valid: bool = false
var overlay: Node3D
var preview: MeshInstance3D
var marker: MeshInstance3D
var preview_material: StandardMaterial3D

func begin(map: WorldMapScene, infr_domain: Enums.InfrDomain) -> void:
	clear()
	world = map
	domain = infr_domain
	# No owner: these editor-only visuals never enter the saved scene.
	overlay = Node3D.new()
	overlay.name = "InfrastructureDrawingPreview"
	world.add_child(overlay)
	overlay.top_level = true
	overlay.global_transform = Transform3D.IDENTITY
	preview_material = StandardMaterial3D.new()
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.albedo_color = Color.ORANGE if domain == Enums.InfrDomain.ROAD else Color.CYAN
	preview = MeshInstance3D.new()
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.add_child(preview)
	marker = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	marker.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.LIME_GREEN
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.add_child(marker)
	marker.hide()
	refresh_endpoints()

func clear() -> void:
	if is_instance_valid(overlay):
		overlay.free()
	overlay = null
	world = null
	points.clear()
	endpoints.clear()
	candidate = null
	placement_valid = false

func refresh_endpoints() -> void:
	endpoints.clear()
	if not is_instance_valid(world):
		return
	for node: Node in world.find_children("*", "", true, false):
		if node is EditorInfrLine3D and node.infr_domain == domain:
			endpoints.append(node)

func hide_pointer() -> void:
	placement_valid = false
	candidate = null
	if is_instance_valid(marker):
		marker.hide()
	redraw()

func update_pointer(camera: Camera3D, mouse: Vector2, terrain_point: Vector3, terrain_valid: bool) -> void:
	placement_valid = terrain_valid
	placement = terrain_point
	var best: float = SNAP_PIXELS
	var selected: EditorInfrLine3D = null
	var selected_index: int = -1
	# Keep the previous endpoint slightly longer to avoid flicker between targets.
	if is_instance_valid(candidate) and candidate.is_inside_tree() and candidate.curve and candidate_index < candidate.curve.point_count:
		var held: Vector3 = candidate.to_global(candidate.curve.get_point_position(candidate_index))
		if eligible(camera, mouse, held, terrain_point, terrain_valid, RELEASE_PIXELS):
			selected = candidate
			selected_index = candidate_index
	if selected == null:
		for line: EditorInfrLine3D in endpoints:
			if not is_instance_valid(line) or not line.is_inside_tree() or not line.curve or line.curve.point_count == 0:
				continue
			for idx: int in [0, line.curve.point_count - 1]:
				var position: Vector3 = line.to_global(line.curve.get_point_position(idx))
				if eligible(camera, mouse, position, terrain_point, terrain_valid, best):
					best = camera.unproject_position(position).distance_to(mouse)
					selected = line
					selected_index = idx
	candidate = selected
	candidate_index = selected_index
	marker.visible = candidate != null
	if candidate != null:
		# Copy the full world position, including elevation; no connection is created.
		placement = candidate.to_global(candidate.curve.get_point_position(candidate_index))
		placement_valid = true
		marker.global_position = placement
		var viewport_height: float = maxf(camera.get_viewport().get_visible_rect().size.y, 1.0)
		var visible_height: float = camera.size if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 2.0 * camera.global_position.distance_to(placement) * tan(deg_to_rad(camera.fov) * 0.5)
		marker.scale = Vector3.ONE * maxf(visible_height / viewport_height * 6.0, 0.02)
	redraw()

func eligible(camera: Camera3D, mouse: Vector2, position: Vector3, terrain_point: Vector3, terrain_valid: bool, radius: float) -> bool:
	return not camera.is_position_behind(position) \
		and (not terrain_valid or position.distance_to(terrain_point) <= SNAP_WORLD_DISTANCE) \
		and camera.unproject_position(position).distance_to(mouse) <= radius

func add_point(_terrain_position: Vector3) -> void:
	if not placement_valid:
		return
	if points.is_empty() or points.back().distance_to(placement) > 0.001:
		points.append(placement)
	redraw()

func remove_last() -> void:
	if not points.is_empty():
		points.pop_back()
	redraw()

func make_curve(include_pointer: bool) -> Curve3D:
	var curve := Curve3D.new()
	for point: Vector3 in points:
		curve.add_point(point)
	if include_pointer and placement_valid and not points.is_empty() and points.back().distance_to(placement) > 0.001:
		curve.add_point(placement)
	InfrUtils.smooth_curve3d(curve)
	return curve

func redraw() -> void:
	if not is_instance_valid(preview):
		return
	var curve: Curve3D = make_curve(true)
	var mesh := ImmediateMesh.new()
	if curve.point_count > 1:
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, preview_material)
		for point: Vector3 in curve.tessellate(6, 2.0):
			mesh.surface_add_vertex(point)
		mesh.surface_end()
	preview.mesh = mesh

# Accept the editor history interface; tests can supply an isolated UndoRedo adapter.
func finish(history: Object) -> bool:
	if points.size() < 2 or not is_instance_valid(world):
		return false
	var container: Node3D
	var next_num: int = 1
	# Re-scan on commit: undo/redo and manual scene edits can change the ID range.
	for node: Node in world.find_children("*", "", true, false):
		if (domain == Enums.InfrDomain.ROAD and node is GeneratedRoadWays) or (domain == Enums.InfrDomain.RAIL and node is GeneratedRailLines):
			container = node as Node3D
		if node is EditorInfrLine3D and node.infr_domain == domain:
			next_num = maxi(next_num, node.num + 1)
	if container == null:
		push_warning("Cannot draw infrastructure: this map has no matching EditorRoads/EditorRails container.")
		return false
	var parent: Node3D = container
	var new_group: Node3D
	if domain == Enums.InfrDomain.ROAD:
		var group_min: int = (next_num / 50) * 50
		var group_name: String = "%d__%d" % [group_min, group_min + 49]
		parent = container.get_node_or_null(group_name) as Node3D
		if parent == null:
			new_group = Node3D.new()
			new_group.name = group_name
			parent = new_group
	var line: EditorInfrLine3D = EditorInfrLine3D.of(domain, next_num, "Drawn road" if domain == Enums.InfrDomain.ROAD else "Drawn rail", true)
	# The overlay uses world coordinates. Store the saved curve in its parent's
	# local coordinates, so translated infrastructure containers work correctly.
	var parent_transform: Transform3D = container.global_transform if new_group != null else parent.global_transform
	line.position = parent_transform.affine_inverse() * points[0]
	line.curve = Curve3D.new()
	var world_curve: Curve3D = make_curve(false)
	var inverse: Transform3D = parent_transform.affine_inverse()
	# Convert the already smoothed handles as vectors, rather than smoothing
	# again in local space (nonuniform parent scale would change the preview).
	for idx: int in range(points.size()):
		line.curve.add_point(inverse * points[idx] - line.position,
			inverse.basis * world_curve.get_point_in(idx), inverse.basis * world_curve.get_point_out(idx))
	history.create_action("Create road" if domain == Enums.InfrDomain.ROAD else "Create rail", UndoRedo.MERGE_DISABLE, world)
	if new_group != null:
		history.add_do_method(container, "add_child", new_group, true)
		history.add_do_method(new_group, "set_owner", world)
	history.add_do_method(parent, "add_child", line, true)
	history.add_do_method(line, "set_owner", world)
	if domain == Enums.InfrDomain.ROAD:
		history.add_do_property(container, "curr_max_road_num", next_num)
		history.add_undo_property(container, "curr_max_road_num", container.curr_max_road_num)
	history.add_undo_method(parent, "remove_child", line)
	if new_group != null:
		history.add_undo_method(container, "remove_child", new_group)
		history.add_do_reference(new_group)
	history.add_do_reference(line)
	history.commit_action()
	points.clear()
	refresh_endpoints()
	hide_pointer()
	return true
