extends RefCounted

const Connections = preload("res://addons/hinterland_tools/road_endpoint_connections.gd")
const Store = preload("res://addons/hinterland_tools/infr_json_store.gd")
var failures: int = 0
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run(tree: SceneTree) -> int:
	for test: String in ["test_visible_connections", "test_saved_connections"]:
		check(call(test, tree) == true, test + " completed")
	print("Road connection tests: %d checks, %d failures" % [checks, failures])
	return 1 if failures else 0

func line(parent: Node, id: int, points: Array[Vector3], domain: Enums.InfrDomain = Enums.InfrDomain.ROAD) -> EditorInfrLine3D:
	var road: EditorInfrLine3D = EditorInfrLine3D.of(domain, id)
	road.curve = Curve3D.new()
	for point: Vector3 in points:
		road.curve.add_point(point)
	parent.add_child(road)
	return road

func test_visible_connections(tree: SceneTree) -> bool:
	var world := WorldMapScene.new()
	world.map_key = "__connection_test__"
	tree.root.add_child(world)
	var source := GeneratedRoadWays.new()
	world.add_child(source)
	var a: EditorInfrLine3D = line(source, 1, [Vector3(-10, 0, 0), Vector3.ZERO])
	var cache: Node3D = Store.container_for(world, Enums.InfrDomain.ROAD)
	cache.show()
	var b: EditorInfrLine3D = line(cache, 2, [Vector3.ZERO, Vector3(10, 0, 0)])
	var c: EditorInfrLine3D = line(cache, 3, [Vector3.ZERO, Vector3(0, 0, 10)])
	line(cache, 4, [Vector3(0, 0.5, 0), Vector3(10, 0.5, 0)])
	line(cache, 5, [Vector3(0, 0, -5), Vector3.ZERO, Vector3(0, 0, 5)])
	var hidden: EditorInfrLine3D = line(source, 6, [Vector3.ZERO, Vector3.ONE])
	hidden.hide()
	line(cache, 7, [Vector3.ZERO, Vector3.ONE], Enums.InfrDomain.RAIL)
	var service: Node = Connections.ensure(world)
	for road: Node3D in Connections.visible_roads(world):
		road._register_connections()
	service.rebuild()
	check(a.get_parent() == source and source.visible, "Visible EditorObjects roads are not adopted or hidden by cache")
	check(a.end_connections.size() == 2 and b.start_connections.size() == 2 and c.start_connections.size() == 2, "Three roads connect reciprocally across cache and source")
	check(a.start_connections.is_empty(), "Open endpoint remains unconnected")
	check(a.end_connections[0].endpoint == 0, "Inspector identifies the neighboring endpoint")
	var markers: int = 0
	for road: Node3D in Connections.visible_roads(world):
		for marker: MeshInstance3D in road._junction_markers:
			if is_instance_valid(marker) and marker.visible:
				markers += 1
				check(marker.owner == null, "Junction marker is not saved geometry")
	check(markers == 1, "Only one marker is drawn for a shared junction")
	b.position = Vector3(3, 0, 0)
	b.force_update_transform()
	check(service.pending, "Transform changes request a coalesced connection update")
	service.rebuild()
	check(a.end_connections.size() == 1 and b.start_connections.is_empty(), "Moving a road removes stale connections")
	c.hide()
	service.rebuild()
	check(a.end_connections.is_empty() and c.start_connections.is_empty(), "Hidden roads no longer contribute connections")
	c.show()
	cache.remove_child(c)
	service.rebuild()
	check(a.end_connections.is_empty(), "Removing a road updates the junction")
	cache.add_child(c)
	service.rebuild()
	check(a.end_connections.size() == 1, "Restoring a road restores its connections")
	c.curve.set_point_position(0, Vector3(2, 0, 0))
	check(service.pending, "Curve edits request a shared connection update")
	service.rebuild()
	check(a.end_connections.is_empty(), "Moving a curve endpoint clears its old junction")
	c.curve.set_point_position(0, Vector3.ZERO)
	service.rebuild()
	# A cached copy temporarily suppresses only the same source ID, not all roads.
	var duplicate: EditorInfrLine3D = line(cache, 1, [Vector3(-10, 0, 0), Vector3.ZERO])
	preload("res://addons/hinterland_tools/editor_cache.gd").refresh_source_visibility(world, Enums.InfrDomain.ROAD)
	check(not a.visible and source.visible, "Cached duplicate does not hide the entire source container")
	duplicate.free()
	preload("res://addons/hinterland_tools/editor_cache.gd").refresh_source_visibility(world, Enums.InfrDomain.ROAD)
	check(a.visible and not hidden.visible, "Flushing restores only cache-suppressed source roads")
	# Pointer candidates are cached at activation, but a later hide must also
	# release an already latched target (and must never snap to JSON-only roads).
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 20, 20)
	camera.look_at(Vector3(-10, 0, 0))
	var drawing = load("res://addons/hinterland_tools/infr_drawing_tool.gd").new()
	drawing.begin(world, Enums.InfrDomain.ROAD)
	var mouse: Vector2 = camera.unproject_position(Vector3(-10, 0, 0))
	drawing.update_pointer(camera, mouse, Vector3(-10, 0, 0), true)
	check(drawing.candidate == a, "Visible source endpoint can be snapped")
	a.hide()
	drawing.update_pointer(camera, mouse, Vector3(-10, 0, 0), true)
	check(drawing.candidate != a, "Hiding the latched snap target releases it")
	drawing.clear()
	world.free()
	return true

func record(id: int, start: Array, end: Array) -> Dictionary:
	return {"num": id, "type": "rural_road", "points": [{"pos": start}, {"pos": end}]}

func test_saved_connections(tree: SceneTree) -> bool:
	var records: Dictionary = {
		1: record(1, [-10, 0, 0], [0, 0, 0]),
		2: record(2, [0, 0, 0], [10, 0, 0]),
		3: record(3, [0.01, 0, 0], [0, 0, 10]),
		4: record(4, [0, 0.5, 0], [10, 0.5, 0]),
	}
	records[1].points[0]["cross"] = {"connectiveRoads": [99], "custom": "keep"}
	var self_links: Array = Connections.neighbors([{"id": 8, "end": 0, "pos": Vector3.ZERO}, {"id": 8, "end": 1, "pos": Vector3.ZERO}])
	check(self_links[0].is_empty() and self_links[1].is_empty(), "A loop road cannot connect to itself")
	var boundary: Array = Connections.neighbors([{"id": 1, "end": 0, "pos": Vector3(-0.001, 0, 0)}, {"id": 2, "end": 0, "pos": Vector3(0.001, 0, 0)}])
	check(boundary[0] == [1], "Endpoint hashing handles negative cell boundaries")
	var rounded: Array = Connections.neighbors([{"id": 1, "end": 0, "pos": Vector3(0.0049, 0.0049, 0)}, {"id": 2, "end": 0, "pos": Vector3(0.019, 0.019, 0)}])
	check(rounded[0].is_empty(), "Editor matching uses rounded geometry consistently with JSON saving")
	Connections.update_json(records)
	check(records[1].points[1].cross.connectiveRoads == [2, 3], "Save connects all coincident road endpoints")
	check(records[2].points[0].cross.connectiveRoads == [1, 3], "Save writes reciprocal links")
	check(not records[4].points[0].has("cross"), "A height-separated road is not a crossing")
	check(records[1].points[0].cross.connectiveRoads == [99] and records[1].points[0].cross.custom == "keep", "Existing manual links and custom metadata survive")
	var before: String = JSON.stringify(records)
	Connections.update_json(records)
	check(JSON.stringify(records) == before, "Repeated crossing generation is idempotent")
	# Simulate JSON's numeric decoding before moving a connected endpoint.
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(records))
	var reread: Dictionary = {}
	for id: String in decoded:
		reread[int(id)] = decoded[id]
	reread[2].points[0].pos = [5, 0, 0]
	Connections.update_json(reread)
	check(2 not in reread[1].points[1].cross.connectiveRoads and reread[2].points[0].cross.connectiveRoads.is_empty(), "Moving an endpoint removes both sides of generated links after JSON reload")
	check(reread[1].points[0].cross.custom == "keep", "Automatic cleanup does not touch manual metadata")
	var directory: String = "/tmp/road-connections-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("roads.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify([record(1, [-10, 0, 0], [0, 0, 0])]))
	file.close()
	var original: String = FileAccess.get_file_as_string(path)
	var road: EditorInfrLine3D = line(tree.root, 2, [Vector3.ZERO, Vector3(10, 0, 0)])
	var store := Store.new()
	var roads: Array[EditorInfrLine3D] = [road]
	var saved: Dictionary = store.save_lines(path, roads, Enums.InfrDomain.ROAD)
	check(saved.ok and FileAccess.get_file_as_string(saved.backup) == original, "Crossing save retains an exact backup")
	var data: Array = Store.read_records(path).records
	check(int(data[0].points[1].cross.connectiveRoads[0]) == 2 and int(data[1].points[0].cross.connectiveRoads[0]) == 1, "JSON save updates cached and existing road records together")
	var runtime: RoadData = RoadMapper.road_from_data_json(data[0])
	check(runtime.nodes[1].cross.connecting_roads == [2], "Generated crossings load into the existing runtime RoadCross model")
	runtime.nodes[1].cross = null
	runtime.crosses.clear()
	runtime.nodes.clear()
	road.free()
	for name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	return true
