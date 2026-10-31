extends RefCounted

const Selection = preload("res://addons/hinterland_tools/object_selection_tool.gd")
const LinePicker = preload("res://addons/hinterland_tools/infr_line_picker.gd")
const Signals = preload("res://addons/hinterland_tools/editor_signals.gd")
const Cache = preload("res://addons/hinterland_tools/editor_cache.gd")
var failures: int = 0
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run(tree: SceneTree) -> int:
	for test: String in ["test_selection", "test_save_requests"]:
		check(call(test, tree) == true, test + " completed")
	print("Editor selection tests: %d checks, %d failures" % [checks, failures])
	return 1 if failures else 0

func line(parent: Node, domain: Enums.InfrDomain, num: int, points: Array[Vector3]) -> EditorInfrLine3D:
	var result: EditorInfrLine3D = EditorInfrLine3D.of(domain, num, "Selection fixture")
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
	var selector := Selection.new()
	var mouse: Vector2 = camera.unproject_position(Vector3.ZERO)
	var hit: Dictionary = selector.pick(world, camera, mouse)
	check(not hit.is_empty() and hit.target == road, "Clicking the middle selects the semantic road, not its mesh or scene root")
	check(hit.label.contains("ID 1"), "Picker supplies the road ID for selection feedback")
	check(hit.world_position.distance_to(Vector3.ZERO) < 0.01, "Selection returns a world-space hit position")
	check(selector.pick(world, camera, mouse + Vector2(0, 40)).is_empty(), "Clicks outside the pixel tolerance miss")
	road.hide()
	check(selector.pick(world, camera, mouse).is_empty(), "Hidden roads cannot be selected")
	road.show()
	var rail: EditorInfrLine3D = line(cache, Enums.InfrDomain.RAIL, 2, [Vector3(-5, 0, 5), Vector3(5, 0, 5)])
	hit = selector.pick(world, camera, mouse)
	check(hit.target == rail, "Overlapping lines prefer the front rail, including cached geometry")
	check(selector.pick(world, camera, mouse, {"max_depth": 10.0}).is_empty(), "Terrain in front blocks line selection")
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
	check(selector.pick(world, camera, camera.unproject_position(Vector3.ZERO)).is_empty(), "Behind-camera geometry cannot create mirrored hits")
	var clip: PackedVector3Array = LinePicker.clip_segment(Vector3(0, 0, 1), Vector3(0, 0, -2), Transform3D.IDENTITY, 0.1, 100.0)
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

func test_save_requests(tree: SceneTree) -> bool:
	var bus: Node = Signals.new()
	tree.root.add_child(bus)
	var world := WorldMapScene.new()
	tree.root.add_child(world)
	var cache: Node3D = Cache.ensure_container(world, Enums.InfrDomain.ROAD)
	var requests: Array = []
	bus.infrastructure_save_requested.connect(func(sender: Node3D, domain: int) -> void: requests.append([sender, domain]))
	cache.do_save_roads_json()
	cache.do_save_rails_json()
	check(requests.size() == 2, "Both Inspector buttons emit EditorSignals save requests")
	check(requests[0][0] == cache and requests[0][1] == Enums.InfrDomain.ROAD, "Road request identifies its cache and domain")
	check(requests[1][0] == cache and requests[1][1] == Enums.InfrDomain.RAIL, "Rail request identifies its cache and domain")
	check(Signals.instance == bus, "Cache actions use the active plugin-owned signal bus")
	bus.free()
	check(Signals.instance == null, "Removing the bus clears its static reference")
	world.free()
	return true

class FixedPicker extends RefCounted:
	var target: Node3D
	func get_hits(_world: Node, _camera: Camera3D, _mouse: Vector2, _context: Dictionary) -> Array[Dictionary]:
		return [{"target": target, "world_position": Vector3.ZERO, "depth": 1.0, "screen_distance": 0.0, "label": "Town fixture"}]
