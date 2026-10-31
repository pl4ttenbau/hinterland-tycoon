extends RefCounted

var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run(tree: SceneTree) -> int:
	var world := WorldMapScene.new()
	world.map_key = "__drawing_tests__"
	tree.root.add_child(world)
	var roads: Node3D = GeneratedRoadWays.new()
	world.add_child(roads)
	var rails: Node3D = GeneratedRailLines.new()
	world.add_child(rails)
	var road := EditorInfrLine3D.ofRoad(49)
	roads.add_child(road)
	road.curve = Curve3D.new()
	road.curve.add_point(Vector3.ZERO)
	road.curve.add_point(Vector3(5, 0, 0))
	var rail := EditorInfrLine3D.ofRail(9)
	rails.add_child(rail)
	rail.curve = Curve3D.new()
	rail.curve.add_point(Vector3(0, 0, 2))
	rail.curve.add_point(Vector3(5, 0, 2))
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 20, 20)
	camera.look_at(Vector3.ZERO)
	var tool = load("res://addons/hinterland_tools/infr_drawing_tool.gd").new()
	tool.begin(world, Enums.InfrDomain.ROAD)
	roads = world.get_node("EditorCache")
	world.get_node("EditorCache").show()
	tool.refresh_endpoints()
	check(tool.endpoints.size() == 1, "Road mode excludes rails")
	check(world.get_node("EditorCache").owner == world and roads.owner == world, "Cache, containers and migrated roads belong to the map")
	check(road.get_parent() != roads and road.is_visible_in_tree(), "Visible source roads remain outside the cache and available for snapping")
	var mouse: Vector2 = camera.unproject_position(Vector3.ZERO)
	tool.update_pointer(camera, mouse, Vector3(0, -2, 0), true)
	check(tool.candidate == road and tool.placement == Vector3.ZERO, "Snap copies the exact endpoint height")
	tool.add_point(Vector3(0, -2, 0))
	tool.add_point(Vector3(0, -2, 0))
	check(tool.points.size() == 1, "Duplicate clicks do not add degenerate points")
	tool.update_pointer(camera, Vector2(-1000, -1000), Vector3(10, 3, 10), true)
	check(tool.candidate == null, "Leaving the endpoint releases snapping")
	check(tool.placement.is_equal_approx(Vector3(10, 3.2, 10)), "Terrain placements include the Place On Ground clearance")
	tool.add_point(Vector3(10, 3, 10))
	tool.update_pointer(camera, Vector2(-1000, -1000), Vector3(20, 5, 20), true)
	check(tool.make_curve(true).point_count == 3 and tool.make_curve(false).point_count == 2, "Hover is previewed without becoming a committed point")
	check(tool.make_curve(true).get_point_out(0) != Vector3.ZERO, "Preview uses Catmull-Rom smoothing")
	var history := History.new()
	check(tool.finish(history), "A valid draft commits")
	var created: EditorInfrLine3D = roads.get_node("RoadWay_50")
	check(created.owner == world and created.curve.point_count == 2, "Commit saves only accepted anchors with a unique ID")
	check(created.to_global(created.curve.get_point_position(0)).is_equal_approx(Vector3.ZERO), "Commit leaves snapped endpoint height unchanged")
	check(created.to_global(created.curve.get_point_position(1)).is_equal_approx(Vector3(10, 3.2, 10)), "Commit applies clearance once, matching the preview")
	var undo: UndoRedo = history.undo
	undo.undo()
	check(not roads.has_node("RoadWay_50"), "Undo removes the line")
	undo.redo()
	check(roads.get_node("RoadWay_50") == created and created.owner == world, "Redo restores the owned line")
	tool.points.append(Vector3.ZERO)
	tool.points.append(Vector3.ONE)
	tool.remove_last()
	check(tool.points.size() == 1, "Backspace removes the last anchor")
	tool.hide_pointer()
	tool.add_point(Vector3.ZERO)
	check(tool.points.size() == 1 and not tool.marker.visible, "Invalid pointer cannot place points")
	tool.begin(world, Enums.InfrDomain.RAIL)
	rails = world.get_node("EditorCache")
	check(tool.points.is_empty() and tool.endpoints.size() == 1, "Switching mode cancels the draft and filters targets")
	tool.points.append(Vector3.ZERO)
	tool.points.append(Vector3(10, 2, 5))
	check(tool.finish(history), "Rail draft commits")
	check(rails.has_node("RailTrack_10"), "Rail commit uses a unique rail ID")
	check(not tool.finish(history), "An empty draft cannot commit")
	tool.clear()
	check(tool.overlay == null, "Cleanup removes temporary visuals")
	undo.clear_history()
	undo.free()
	world.free()
	print("Infrastructure drawing tests: %d failures" % failures)
	return 1 if failures else 0

# Exercise the exact registered do/undo operations without a live editor singleton.
class History extends RefCounted:
	var undo := UndoRedo.new()
	func create_action(title: String, merge: int, _context: Object) -> void:
		undo.create_action(title, merge)
	func add_do_method(object: Object, method: String, first: Variant, second: Variant = null) -> void:
		undo.add_do_method(Callable(object, method).bind(first) if second == null else Callable(object, method).bind(first, second))
	func add_undo_method(object: Object, method: String, arg: Variant) -> void:
		undo.add_undo_method(Callable(object, method).bind(arg))
	func add_do_property(object: Object, property: String, value: Variant) -> void:
		undo.add_do_property(object, property, value)
	func add_undo_property(object: Object, property: String, value: Variant) -> void:
		undo.add_undo_property(object, property, value)
	func add_do_reference(object: Object) -> void:
		undo.add_do_reference(object)
	func commit_action() -> void:
		undo.commit_action()
