## Regression checks for viewport selection, node markers and toolbar controls.
class_name EditorSelectionSuite extends RefCounted

var failures: int = 0
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run(tree: SceneTree) -> int:
	for test: String in ["test_toolbar", "test_editor_data", "test_selection", "test_node_markers", "test_save_requests"]:
		check(call(test, tree) == true, test + " completed")
	print("Editor selection tests: %d checks, %d failures" % [checks, failures])
	return 1 if failures else 0

func test_toolbar(tree: SceneTree) -> bool:
	var panel: Control = load("res://addons/hinterland_tools/editor_tools_panel.tscn").instantiate()
	tree.root.add_child(panel)
	var buttons: Dictionary[Enums.EnumEditorTool, Button] = HinterlandEditorPlugin.create_tool_buttons(panel)
	for tool: Enums.EnumEditorTool in buttons:
		if tool == Enums.EnumEditorTool.NONE:
			continue
		buttons[tool].button_pressed = true
		for other: Enums.EnumEditorTool in buttons:
			check(buttons[other].button_pressed == (other == tool), "Selecting a toolbar tool releases every conflicting tool")
	var other_panel: Control = load("res://addons/hinterland_tools/editor_tools_panel.tscn").instantiate()
	tree.root.add_child(other_panel)
	var other_buttons: Dictionary[Enums.EnumEditorTool, Button] = HinterlandEditorPlugin.create_tool_buttons(other_panel)
	buttons[Enums.EnumEditorTool.SELECT_OBJECT].button_pressed = true
	other_buttons[Enums.EnumEditorTool.SELECT_OBJECT].button_pressed = true
	check(buttons[Enums.EnumEditorTool.SELECT_OBJECT].button_pressed, "A second panel cannot release this panel's selected tool")
	other_panel.free()
	panel.free()
	return true

func test_editor_data(_tree: SceneTree) -> bool:
	check(not EditorActionResult.failure("").ok, "A failed action cannot accidentally appear successful with an empty message")
	check(not InfrCatalogReadResult.from_json({}).ok, "Read results reject non-array catalog data before publication")
	check(not InfrCatalogReadResult.from_json([{"num": 1, "points": []}]).ok, "Catalog results reject invalid geometry")
	var missing: InfrCatalogReadResult = InfrCatalogReadResult.read("/tmp/missing-editor-catalog-%d.json" % OS.get_process_id())
	check(missing.ok and not missing.exists and missing.records.is_empty(), "Missing-file state remains distinct from invalid JSON")
	var definition: Dictionary = {"num": 0, "interchangeNum": 0, "domain": "ROAD", "nodeIndex": 0}
	var placement: EditorStopLabelPlacement = EditorStopLabelPlacement.from_definition(definition, "Stop", Vector3.ZERO)
	check(placement != null and placement.stop_num == 0 and placement.node_index == 0, "Placement factory preserves valid zero IDs and indices")
	check(EditorStopLabelPlacement.from_definition(definition, "", Vector3.ZERO) == null, "Placement validation rejects unnamed labels")
	check(EditorStopLabelPlacement.from_definition(definition, "Stop", Vector3(INF, 0, 0)) == null, "Placement validation rejects nonfinite positions")
	definition["nodeIndex"] = 0.5
	check(EditorStopLabelPlacement.from_definition(definition, "Stop", Vector3.ZERO) == null, "Placement validation rejects fractional node indices")
	return true

func line(parent: Node, domain: Enums.InfrDomain, num: int, points: Array[Vector3]) -> EditorInfrLine3D:
	var result: EditorInfrLine3D = EditorInfrLine3D.of(domain, num, "ObjectSelectedTool fixture")
	result.curve = Curve3D.new()
	for point: Vector3 in points:
		result.curve.add_point(point)
	parent.add_child(result)
	return result

func test_selection(tree: SceneTree) -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.own_world_3d = true
	tree.root.add_child(viewport)
	var world := WorldMapScene.new()
	viewport.add_child(world)
	var source := Node3D.new()
	source.name = "EditorObjects"
	world.add_child(source)
	var cache := Node3D.new()
	cache.name = "EditorCache"
	world.add_child(cache)
	var road: EditorInfrLine3D = line(source, Enums.InfrDomain.ROAD, 1, [Vector3(-5, 0, 0), Vector3(5, 0, 0)])
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 0, 20)
	camera.current = true
	var selector := ObjectSelectedTool.new()
	var mouse: Vector2 = camera.unproject_position(Vector3.ZERO)
	var hit: EditorPickHit = selector.pick(world, camera, mouse)
	check(hit != null and hit.target == road, "Clicking the middle selects the semantic road, not its mesh or scene root")
	check(hit.label.contains("ID 1"), "Picker supplies the road ID for selection feedback")
	check(hit.world_position.distance_to(Vector3.ZERO) < 0.01, "ObjectSelectedTool returns a world-space hit position")
	check(selector.pick(world, camera, mouse + Vector2(0, 40)) == null, "Clicks outside the pixel tolerance miss")
	road.hide()
	check(selector.pick(world, camera, mouse) == null, "Hidden roads cannot be selected")
	road.show()
	var rail: EditorInfrLine3D = line(cache, Enums.InfrDomain.RAIL, 2, [Vector3(-5, 0, 5), Vector3(5, 0, 5)])
	hit = selector.pick(world, camera, mouse)
	check(hit.target == rail, "Overlapping lines prefer the front rail, including cached geometry")
	check(selector.pick(world, camera, mouse, 10.0) == null, "Terrain in front blocks line selection")
	rail.hide()
	# Unequal endpoint depths exercise perspective-correct interpolation.
	road.curve.set_point_position(0, Vector3(-5, 0, 10))
	road.curve.set_point_position(1, Vector3(5, 0, -10))
	hit = selector.pick(world, camera, mouse)
	check(hit.world_position.distance_to(Vector3.ZERO) < 0.02, "Perspective hit reconstruction remains on the projected click ray")
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20
	check(selector.pick(world, camera, camera.unproject_position(Vector3.ZERO)).target == road, "Orthographic cameras support line picking")
	road.hide()
	var behind: EditorInfrLine3D = line(source, Enums.InfrDomain.ROAD, 3, [Vector3(-2, 0, 30), Vector3(2, 0, 30)])
	check(selector.pick(world, camera, camera.unproject_position(Vector3.ZERO)) == null, "Behind-camera geometry cannot create mirrored hits")
	var clip: PackedVector3Array = InfrLinePicker.clip_segment(Vector3(0, 0, 1), Vector3(0, 0, -2), Transform3D.IDENTITY, 0.1, 100.0)
	check(clip.size() == 2 and is_equal_approx(clip[0].z, -0.1), "Segments crossing the camera near plane are clipped")
	behind.hide()
	road.show()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	road.curve.clear_points()
	for point: Vector3 in [Vector3(-5, 0, 0), Vector3(0, 4, 0), Vector3(5, 0, 0)]:
		road.curve.add_point(point)
	InfrUtils.smooth_curve3d(road.curve)
	source.position = Vector3(1, -2, -3)
	source.rotation.y = 0.4
	source.scale = Vector3(2, 1, 0.5)
	var curved_point: Vector3 = road.to_global(road.curve.sample(0, 0.5))
	check(selector.pick(world, camera, camera.unproject_position(curved_point)).target == road, "Curved lines remain pickable under translated, rotated and scaled source containers")
	road.hide()
	# Future categories return the same generic hit contract. No infrastructure
	# fields are required on the semantic object selected by the coordinator.
	var town := Node3D.new()
	world.add_child(town)
	var picker := FixedPicker.new()
	picker.target = town
	selector.register_picker(picker)
	selector.register_picker(picker)
	check(selector.pickers.size() == 2 and selector.pick(world, camera, mouse).target == town, "Additional picker types can register once and return their own semantic targets")
	viewport.free()
	return true

func test_node_markers(tree: SceneTree) -> bool:
	var world := Node3D.new()
	tree.root.add_child(world)
	var road: EditorInfrLine3D = line(world, Enums.InfrDomain.ROAD, 1, [Vector3.ZERO, Vector3(5, 0, 0), Vector3(10, 1, 0)])
	var rail: EditorInfrLine3D = line(world, Enums.InfrDomain.RAIL, 2, [Vector3.ZERO, Vector3(0, 0, 5)])
	var markers := InfrLineNodeMarkers.new()
	tree.root.add_child(markers)
	markers.show_line(road)
	var visual: Node3D = markers._visual
	check(visual.get_child_count() == 3, "Only the selected line's actual curve nodes receive markers")
	check(visual.get_child(0).mesh is BoxMesh and visual.get_child(1).mesh is SphereMesh, "Index zero is a cube; subsequent nodes are round")
	check(visual.owner == null and visual.get_child(0).owner == null, "ObjectSelectedTool markers are never owned by the saved scene")
	check(road.get_children().find(visual) == -1, "Internal markers stay out of ordinary authoring child traversal")
	var overlay_material: StandardMaterial3D = visual.get_child(1).material_override
	check(overlay_material.no_depth_test and overlay_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and overlay_material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED and overlay_material.render_priority == Material.RENDER_PRIORITY_MAX, "Markers render as a foreground overlay after opaque and transparent geometry")
	world.position = Vector3(4, 2, 3)
	world.rotation.y = 0.5
	world.scale = Vector3(2, 1, 0.5)
	check(visual.get_child(2).global_position.is_equal_approx(road.to_global(road.curve.get_point_position(2))), "Markers follow translated, rotated and scaled infrastructure")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 100))
	for projection: int in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		for distance: float in [100.0, 1000.0]:
			camera.global_position.z = distance
			markers.update_view(camera)
			var marker: MeshInstance3D = visual.get_child(1)
			var projected_size: float = camera.unproject_position(marker.global_position).distance_to(camera.unproject_position(marker.global_position + camera.global_basis.y * marker.global_basis.y.length()))
			check(absf(projected_size - 14.0) < 0.1, "Round markers retain a 14-pixel diameter across camera distance/projection and parent scale")
	road.curve.set_point_position(1, Vector3(6, 2, 1))
	check(not visual.visible and markers._visual.get_child(1).position == Vector3(6, 2, 1), "Curve edits replace the preview immediately")
	var replacement := Curve3D.new()
	replacement.add_point(Vector3.ZERO)
	replacement.add_point(Vector3.ONE)
	road.curve = replacement
	check(markers._visual.get_child_count() == 2, "Replacing the curve refreshes marker count")
	visual = markers._visual
	markers.show_line(rail)
	check(not visual.visible and markers._visual.get_parent() == rail, "Selecting another line removes the previous markers")
	visual = markers._visual
	markers.clear()
	check(not visual.visible and markers._visual == null, "Deselecting clears the overlay")
	markers.update_selection([], road)
	check(markers._visual != null, "Inspector-only selection of a locked line restores its markers")
	markers._visual.free()
	markers.update_selection([], road)
	check(is_instance_valid(markers._visual), "Repeated selection repairs a removed overlay on the same line")
	markers.update_selection([rail], rail.curve)
	check(markers._visual.get_parent() == rail, "Inspecting the curve resource keeps its selected line's markers")
	markers.update_selection([], world)
	check(markers._visual == null, "Selecting another object clears inspector-only markers")
	markers.show_line(road)
	world.remove_child(road)
	check(markers._visual == null, "Undo/removing the selected line clears its overlay")
	road.free()
	markers.show_line(rail)
	visual = markers._visual
	markers.free()
	check(not visual.visible, "Unloading the plugin clears its selected-line overlay")
	world.free()
	return true

func test_save_requests(tree: SceneTree) -> bool:
	var bus: Node = HinterlandEditorSignals.new()
	tree.root.add_child(bus)
	var world := WorldMapScene.new()
	tree.root.add_child(world)
	var cache: Node3D = EditorCache.ensure_container(world, Enums.InfrDomain.ROAD)
	var requests: Array = []
	bus.infrastructure_save_requested.connect(func(sender: Node3D, domain: int) -> void: requests.append([sender, domain]))
	cache.do_save_roads_json()
	cache.do_save_rails_json()
	check(requests.size() == 2, "Both Inspector buttons emit EditorSignals save requests")
	check(requests[0][0] == cache and requests[0][1] == Enums.InfrDomain.ROAD, "Road request identifies its cache and domain")
	check(requests[1][0] == cache and requests[1][1] == Enums.InfrDomain.RAIL, "Rail request identifies its cache and domain")
	check(HinterlandEditorSignals.instance == bus, "EditorCache actions use the active plugin-owned signal bus")
	bus.free()
	check(HinterlandEditorSignals.instance == null, "Removing the bus clears its static reference")
	world.free()
	return true

class FixedPicker extends EditorObjectPicker:
	var target: Node3D
	func get_hits(_world: Node, _camera: Camera3D, _mouse: Vector2, _max_depth: float = INF) -> Array[EditorPickHit]:
		var hit: EditorPickHit = EditorPickHit.at_position(Vector3.ZERO, 1.0, 0.0)
		hit.target = target
		hit.label = "Town fixture"
		return [hit]
