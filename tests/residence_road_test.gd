extends Node3D

const CONNECTOR = preload("res://game/gamescripts/services/importexport/infr/connectors/residence_road_connector.gd")
const DOOR = preload("res://game/gamescripts/nodes/structures/residence_door.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	check(test_connections(), "Connection checks complete")
	check(test_door(), "Door checks complete")
	check(test_editor_batch(), "Editor batch checks complete")
	print("Residence road tests: %d failures" % failures)
	get_tree().quit(1 if failures > 0 else 0)

func test_connections() -> bool:
	var curve := Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(100, 0, 0))
	var road := RoadData.of(7, "rural_road")
	road.start_pos = Vector3(10, 4, 20)
	road.curve = curve
	var roads: Array[RoadData] = [road]
	var found = CONNECTOR.find_on_roads(Vector3(40, 4, 25), roads)
	check(found != null and found.road_num == 7 and is_equal_approx(found.dist_from_zero, 30), "Connection stores distance along road, rather than distance to it")
	check(CONNECTOR.find_on_roads(Vector3(40, 4, 70), roads) != null, "Exactly 50 metres is accepted")
	check(CONNECTOR.find_on_roads(Vector3(40, 4, 70.01), roads) == null, "Beyond 50 metres leaves connection empty")
	check(CONNECTOR.find_on_roads(Vector3(40, 55, 20), roads) == null, "Height difference counts toward the cutoff")
	var closer := RoadData.of(8, "rural_road")
	closer.start_pos = Vector3(10, 4, 24)
	closer.curve = curve
	roads.append(closer)
	check(CONNECTOR.find_on_roads(Vector3(40, 4, 25), roads).road_num == 8, "Nearest road wins")
	var line := EditorInfrLine3D.ofRoad(7)
	line.curve = curve
	line.transform = Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * 2), Vector3(10, 4, 20))
	add_child(line)
	var lines: Array[EditorInfrLine3D] = [line]
	var exit_position: Vector3 = line.to_global(Vector3(30, 0, 0)) + Vector3.UP * 5
	var editor_found = CONNECTOR.find_on_editor_roads(exit_position, lines)
	check(editor_found != null and is_equal_approx(editor_found.dist_from_zero, 60), "Editor rotation and scale preserve world-metre offsets")
	var projected: Curve3D = CONNECTOR.world_curve(curve, line.global_transform)
	check(projected.sample_baked(editor_found.dist_from_zero).distance_to(exit_position) < 5.01, "Stored offset reconstructs the projected road point")
	line.infr_domain = Enums.InfrDomain.RAIL
	check(CONNECTOR.find_on_editor_roads(exit_position, lines) == null, "Rail lines are excluded")
	line.infr_domain = Enums.InfrDomain.ROAD
	line.num = -1
	check(CONNECTOR.find_on_editor_roads(exit_position, lines) == null, "Roads without saved IDs are excluded")
	line.free()
	# A bent road must measure travel along the curve, not a chord from point zero.
	var bent := Curve3D.new()
	bent.add_point(Vector3.ZERO, Vector3.ZERO, Vector3(0, 0, 30))
	bent.add_point(Vector3(30, 0, 30), Vector3(-30, 0, 0))
	road.start_pos = Vector3.ZERO
	road.curve = bent
	var along_bend = CONNECTOR.find_on_roads(Vector3(30, 1, 30), [road])
	check(along_bend != null and along_bend.dist_from_zero > Vector3(30, 0, 30).length() + 5, "Curved-road offset follows the bend")
	check(is_equal_approx(along_bend.dist_from_zero, bent.get_baked_length()), "Curve endpoint offset equals its baked length")
	road.curve = Curve3D.new()
	check(CONNECTOR.find_on_roads(Vector3.ZERO, [road]) == null, "Empty curves are skipped")
	return true

func test_door() -> bool:
	var house := Node3D.new()
	house.transform = Transform3D(Basis(Vector3.UP, PI / 2).scaled(Vector3.ONE * 2), Vector3(20, 3, 40))
	add_child(house)
	var door := DOOR.new()
	house.add_child(door)
	var bounds: AABB = DOOR.ARROW_MESH.get_aabb()
	var mesh_tail: Vector3 = bounds.position + Vector3(bounds.size.x * 0.5, bounds.size.y * 0.5, bounds.size.z)
	var expected: Vector3 = door.global_transform * door.get_arrow_transform() * mesh_tail
	check(door.get_exit_position().is_equal_approx(expected), "Exit is the flat-tail face center under the full house transform")
	check(not door.get_exit_position().is_equal_approx(door.global_position), "Exit differs from marker origin")
	door.rotation.y = PI / 2
	check(not door.get_exit_position().is_equal_approx(expected), "Rotating the door updates the exit")
	check(door.get_child_count() == 0, "Runtime exit calculation needs no preview mesh")
	house.free()
	return true

func test_editor_batch() -> bool:
	var world := Node3D.new()
	add_child(world)
	var collector: Node = load("res://game/gamescripts/nodes/world/collections/world_houses.gd").new()
	world.add_child(collector)
	var house: Node3D = load("res://game/gamescripts/nodes/structures/editor_residence_3d.gd").new()
	collector.add_child(house)
	var door := DOOR.new()
	house.add_child(door)
	var curve := Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(100, 0, 0))
	var source := EditorInfrLine3D.ofRoad(7)
	source.curve = curve
	world.add_child(source)
	var cache := Node3D.new()
	cache.name = "EditorCache"
	world.add_child(cache)
	var edited := EditorInfrLine3D.ofRoad(7)
	edited.curve = curve
	cache.add_child(edited)
	edited.position.z = 100
	collector.do_refresh_road_connections()
	check(house.road_connection == null, "Cached road overrides a nearer, stale source with the same ID")
	edited.position.z = 0
	collector.do_refresh_road_connections()
	check(house.road_connection != null and house.road_connection.road_num == 7, "Batch refresh stores a connection on the editor residence")
	var saved_connection: Resource = house.road_connection
	var preview: Node = load("res://addons/hinterland_tools/residence_road_preview.gd").new()
	add_child(preview)
	preview.update_for_house(house, world)
	var visual: MeshInstance3D = world.get_node_or_null("_ResidenceRoadPreview")
	check(visual != null and visual.owner == null and visual.mesh.get_surface_count() == 1, "Connection preview renders without being saved into the map")
	check(house.road_connection == saved_connection, "Preview does not modify saved connection data")
	edited.position.z = 100
	preview.update_for_house(house, world)
	check(world.get_node_or_null("_ResidenceRoadPreview") == null, "Preview disappears when the road moves beyond 50 metres")
	preview.free()
	collector.do_refresh_road_connections()
	check(house.road_connection == null, "Batch refresh clears stale out-of-range connections")
	world.free()
	return true
