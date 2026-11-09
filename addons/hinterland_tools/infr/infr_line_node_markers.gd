@tool
class_name InfrLineNodeMarkers extends Node

var _line: EditorInfrLine3D
var _visual: Node3D

func _enter_tree() -> void:
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	# Inspector-only picks of locked source lines do not reliably trigger the
	# EditorPlugin's edit/visibility callbacks, especially on repeated clicks.
	update_selection(EditorInterface.get_selection().get_selected_nodes(), EditorInterface.get_inspector().get_edited_object())
	var viewport: SubViewport = EditorInterface.get_editor_viewport_3d(0)
	if is_instance_valid(viewport):
		update_view(viewport.get_camera_3d())

func update_selection(selected: Array[Node], inspected: Object) -> void:
	if is_instance_valid(inspected) and inspected is EditorInfrLine3D:
		show_line(inspected)
		return
	# Keep a selected line visible while its Curve3D resource is being edited.
	for node: Node in selected:
		if node is EditorInfrLine3D:
			show_line(node)
			return
	clear()

func update_view(camera: Camera3D) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(_visual):
		return
	var viewport_height: float = maxf(camera.get_viewport().get_visible_rect().size.y, 1.0)
	for marker: MeshInstance3D in _visual.get_children():
		marker.visible = not camera.is_position_behind(marker.global_position)
		# Use projected depth rather than distance, so off-centre nodes have the
		# same apparent size. Unprojecting also respects orthographic/keep-aspect.
		var screen_position: Vector2 = camera.unproject_position(marker.global_position)
		var depth: float = maxf(-camera.to_local(marker.global_position).z, camera.near)
		var metres_per_pixel: float = camera.project_position(screen_position, depth).distance_to(camera.project_position(screen_position + Vector2(0, 1), depth))
		if viewport_height > 1.0:
			marker.global_basis = Basis.from_scale(Vector3.ONE * metres_per_pixel * 14.0)

func show_line(line: EditorInfrLine3D) -> void:
	if is_instance_valid(_line) and _line == line and is_instance_valid(_visual) and not _visual.is_queued_for_deletion():
		return
	clear()
	if not is_instance_valid(line) or not line.is_inside_tree():
		return
	_line = line
	_line.curve_changed.connect(_redraw)
	_line.tree_exiting.connect(clear)
	_redraw()

func clear() -> void:
	if is_instance_valid(_line):
		_line.curve_changed.disconnect(_redraw)
		_line.tree_exiting.disconnect(clear)
	_line = null
	_clear_visual()

func _clear_visual() -> void:
	if is_instance_valid(_visual):
		_visual.hide()
		_visual.queue_free()
	_visual = null

func _redraw() -> void:
	_clear_visual()
	if not is_instance_valid(_line) or _line.curve == null:
		return
	_visual = Node3D.new()
	_visual.name = "_SelectedLineNodes"
	# Unowned children follow the line's transform/visibility but never enter
	# the saved scene or change the infrastructure's JSON node indices.
	_line.add_child(_visual, false, Node.INTERNAL_MODE_BACK)
	var material: StandardMaterial3D = _create_marker_material(Color("65e6c4"))
	var start_material: StandardMaterial3D = _create_marker_material(Color.LIGHT_GRAY)
	var cube: PrimitiveMesh = _create_marker_mesh(true)
	var sphere: PrimitiveMesh = _create_marker_mesh(false)
	for index: int in range(_line.curve.point_count):
		_add_node_marker(index, cube if index == 0 else sphere, start_material if index == 0 else material)

func _create_marker_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.no_depth_test = true
	# Draw after roads/terrain and transparent water; depth testing alone does
	# not control ordering between opaque and transparent render queues.
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = Material.RENDER_PRIORITY_MAX
	return material

func _create_marker_mesh(is_start: bool) -> PrimitiveMesh:
	if is_start:
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * 1.2
		return cube
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	return sphere

func _add_node_marker(index: int, mesh: Mesh, material: Material) -> void:
	var marker := MeshInstance3D.new()
	marker.name = "Node%d" % index
	marker.mesh = mesh
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_visual.add_child(marker)
	marker.position = _line.curve.get_point_position(index)

func _exit_tree() -> void:
	clear()

func get_marked_line() -> EditorInfrLine3D:
	return _line if is_instance_valid(_line) else null
