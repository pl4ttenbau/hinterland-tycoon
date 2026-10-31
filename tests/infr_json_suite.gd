extends RefCounted

const Store = preload("res://addons/hinterland_tools/infr_json_store.gd")
var failures: int = 0
var checks: int = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run(tree: SceneTree) -> int:
	for test: String in ["test_save", "test_formatting", "test_load", "test_standalone_editorobjects", "test_cache_upgrade", "test_runtime_cache", "test_project_json"]:
		check(call(test, tree) == true, test + " completed")
	print("Infrastructure JSON tests: %d checks, %d failures" % [checks, failures])
	return 1 if failures else 0

func fixture() -> Array:
	return [{"num": 7, "name": "Original", "type": "750_MM", "tag": "keep", "hideBed": true,
		"extension": {"keep": 4}, "points": [
			{"pos": [1, 2, 3], "fork": {"connectiveTracks": [8]}, "custom": "keep"},
			{"pos": [8, 3, 4], "station": {"name": "keep"}}
		]}, {"num": 8, "name": "Unseen", "type": "750_MM", "points": [{"pos": [0, 0, 0]}, {"pos": [3, 0, 0]}]}]

func make_line(tree: SceneTree) -> EditorInfrLine3D:
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRail(7, "Edited")
	tree.root.add_child(line)
	line.position = Vector3(10, 5, -3)
	line.scale = Vector3(2, 3, 4)
	line.curve = Curve3D.new()
	line.curve.add_point(Vector3.ZERO, Vector3.ZERO, Vector3(1, 2, 3))
	line.curve.add_point(Vector3(4, 1, 0), Vector3(-2, -1, 0))
	return line

func test_save(tree: SceneTree) -> bool:
	var directory: String = "/tmp/hinterland-json-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("tracks.json")
	var original: String = JSON.stringify(fixture()) + "\n"
	write_text(path, original)
	var store := Store.new()
	var line: EditorInfrLine3D = make_line(tree)
	var lines: Array[EditorInfrLine3D] = [line]
	var saved: Dictionary = store.save_lines(path, lines, Enums.InfrDomain.RAIL)
	check(saved.ok, "Save succeeds")
	check(FileAccess.get_file_as_string(saved.backup) == original, "Backup preserves the exact original bytes")
	var data: Array = Store.read_records(path).records
	check(data.size() == 2 and data[1].num == 8, "Saving a partial editor scene retains unseen JSON records")
	check(data[0].type == "750_MM" and data[0].tag == "keep" and data[0].hideBed and data[0].extension.keep == 4, "Top-level metadata and actual type survive")
	check(data[0].name == "Edited" and data[0].num == 7, "Actual ID and edited name are saved")
	check(int(data[0].points[0].fork.connectiveTracks[0]) == 8 and data[0].points[1].station.name == "keep", "Fork/station metadata survives")
	check(WorldUtils.vec3_from_float_arr(data[0].points[1].pos) == Vector3(18, 8, -3), "Positions are saved in world coordinates")
	check(WorldUtils.vec3_from_float_arr(data[0].points[0].handleOut) == Vector3(2, 6, 12), "Handle offsets include parent scale without translation")
	var again: Dictionary = store.save_lines(path, lines, Enums.InfrDomain.RAIL)
	check(again.ok and again.backup != saved.backup and FileAccess.file_exists(saved.backup), "Every save retains a separate backup")
	var before: String = FileAccess.get_file_as_string(path)
	line.curve.add_point(Vector3(9, 0, 0))
	check(not store.save_lines(path, lines, Enums.InfrDomain.RAIL).ok and FileAccess.get_file_as_string(path) == before, "Changed point counts cannot silently move station/fork metadata")
	line.curve.remove_point(2)
	lines.append(line)
	check(not store.save_lines(path, lines, Enums.InfrDomain.RAIL).ok, "Duplicate editor IDs are rejected")
	lines.pop_back()
	write_text(path, "{broken")
	check(not store.save_lines(path, lines, Enums.InfrDomain.RAIL).ok and FileAccess.get_file_as_string(path) == "{broken", "Invalid source JSON is never overwritten")
	var new_path: String = directory.path_join("roads.json")
	check(store.save_lines(new_path, lines, Enums.InfrDomain.ROAD).ok, "First save can create a missing JSON file")
	# A directory at the destination forces replacement failure, without touching it.
	var blocked: String = directory.path_join("blocked")
	DirAccess.make_dir_absolute(blocked)
	check(not Store.write_with_backup(blocked, fixture()).ok and DirAccess.dir_exists_absolute(blocked), "Failed replacement leaves the original destination intact")
	DirAccess.remove_absolute(blocked)
	check(not store.save_lines(directory.path_join("missing/roads.json"), lines, Enums.InfrDomain.ROAD).ok, "A failed temporary write does not report success")
	line.free()
	for name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(directory)
	return true

func test_formatting(_tree: SceneTree) -> bool:
	var data: Array = [{"num": 1, "points": [
		{"pos": [2.3934324, 2.4, -0.001], "handleOut": [1.234567890123, 0, 3]},
		{"pos": [-1.236, 100, 3.999]}, {"pos": [-655.125, 1.125, 0.005]}
	], "short": [1, 2, 3], "long": range(60), "note": "literal [1, 2, 3]"}]
	var text: String = Store.format_json(data)
	check(text.contains('"pos": [2.39, 2.40, 0.00]'), "Positions round normally with exactly two decimals")
	check(text.contains('"pos": [-1.24, 100.00, 4.00]'), "Negative values and trailing zeros are formatted correctly")
	check(text.contains('"pos": [-655.13, 1.13, 0.01]'), "Halfway values use normal rounding away from zero")
	check(text.contains('"short": [1, 2, 3]'), "Short numeric arrays stay on one line")
	check(text.contains('"long": [\n'), "Arrays exceeding line width put each value on its own line")
	var parsed: Array = JSON.parse_string(text)
	check(is_equal_approx(parsed[0].points[0].handleOut[0], 1.234567890123), "Handle precision is not reduced to position precision")
	check(parsed[0].note == "literal [1, 2, 3]", "Formatting preserves strings containing array-like text")
	for line: String in text.split("\n"):
		check(line.replace("\t", "    ").length() <= Store.JSON_LINE_WIDTH, "Numeric array layout respects the line width")
	Store.round_positions(data)
	check(is_equal_approx(data[0].points[0].pos[0], 2.39), "Crossing generation uses the rounded saved coordinates")
	return true

func test_load(tree: SceneTree) -> bool:
	var world := WorldMapScene.new()
	world.map_key = "__infr_json_test_%d" % OS.get_process_id()
	var directory: String = "res://world/%s/jsondata" % world.map_key
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var rail_path: String = directory.path_join("tracks.json")
	var road_path: String = directory.path_join("roads.json")
	write_text(rail_path, JSON.stringify(fixture()))
	write_text(road_path, JSON.stringify([{"num": 51, "name": "Road", "type": "dirt_path", "points": [{"pos": [0, 1, 0]}, {"pos": [7, 2, 3]}]}]))
	tree.root.add_child(world)
	var references := Node3D.new()
	references.name = "EditorObjects"
	world.add_child(references)
	references.owner = world
	var roads := GeneratedRoadWays.new()
	references.add_child(roads)
	roads.owner = references
	var rails := GeneratedRailLines.new()
	references.add_child(rails)
	rails.owner = references
	rails.position = Vector3(10, 5, -3)
	rails.scale = Vector3(2, 3, 4)
	var cache: Node3D = Store.container_for(world, Enums.InfrDomain.ROAD)
	cache.show()
	var unsaved: EditorInfrLine3D = EditorInfrLine3D.ofRoad(70, "Unsaved")
	unsaved.curve = Curve3D.new()
	unsaved.curve.add_point(Vector3(100, 1, 0))
	unsaved.curve.add_point(Vector3(110, 2, 3))
	cache.add_child(unsaved)
	unsaved.owner = world
	var store := Store.new()
	var history := History.new()
	var service: Node = preload("res://addons/hinterland_tools/road_endpoint_connections.gd").ensure(world)
	service.edit_history = history
	check(store.load_world(world, Enums.InfrDomain.ROAD).ok, "Load generates saved reference roads")
	check(roads.has_node("RoadWay_51") and not cache.has_node("RoadWay_51"), "Load puts saved roads in EditorObjects, not cache")
	check(unsaved.get_parent() == cache, "Loading preserves unsaved cache contents")
	var source: EditorInfrLine3D = roads.get_node("RoadWay_51")
	check(source.owner == references, "Generated reference geometry belongs to the source subscene")
	var copy: EditorInfrLine3D = service.edit_in_cache(source)
	check(copy.get_parent() == cache and copy.owner == world and copy.num == source.num, "Edit In Cache creates a map-owned copy with the same ID")
	check(copy.curve != source.curve and not source.visible, "Working copy has its own curve and suppresses the reference")
	copy.curve.set_point_position(1, Vector3(8, 2, 4))
	check(source.curve.get_point_position(1) == Vector3(7, 1, 3), "Editing the working copy does not mutate saved reference geometry")
	check(service.edit_in_cache(source) == copy, "Repeated Edit In Cache selects the existing working copy")
	history.undo.undo()
	check(copy.get_parent() == null and source.visible, "Undo discards the edit copy and restores the reference")
	history.undo.redo()
	check(copy.get_parent() == cache and not source.visible, "Redo restores the working copy")
	check(store.load_world(world, Enums.InfrDomain.ROAD).ok and copy.get_parent() == cache, "Reloading references leaves edited copies untouched")
	check(roads.get_child_count() == 1, "Repeated Load does not duplicate references")
	copy.hide()
	var saved: Dictionary = store.save_world(world, Enums.InfrDomain.ROAD)
	check(saved.ok and saved.count == 2, "Save merges hidden cached edits and new roads")
	var data: Array = Store.read_records(road_path).records
	check(data[0].type == "dirt_path", "Editing an existing road preserves its saved type")
	check(WorldUtils.vec3_from_float_arr(data[0].points[1].pos) == Vector3(8, 3, 4), "Saved JSON contains working-copy geometry")
	check(store.load_world(world, Enums.InfrDomain.ROAD).ok, "Successful Save can refresh the reference view")
	store.flush_saved(world, Enums.InfrDomain.ROAD, history)
	check(Store.domain_roots(cache, Enums.InfrDomain.ROAD).is_empty(), "Only unsaved working copies are flushed")
	check(roads.get_child_count() == 2 and roads.get_node("RoadWay_51").visible, "Saved roads remain visible in EditorObjects after flushing")
	check(store.save_world(world, Enums.InfrDomain.ROAD).ok and Store.read_records(road_path).records.size() == 2, "Saving an empty cache preserves saved roads")
	# An external JSON deletion must not be resurrected from stale reference nodes.
	write_text(road_path, JSON.stringify([data[0]]))
	check(store.save_world(world, Enums.InfrDomain.ROAD).ok and Store.read_records(road_path).records.size() == 1, "Reference geometry cannot write back an externally deleted road")
	check(store.load_world(world, Enums.InfrDomain.ROAD).ok and roads.get_child_count() == 1, "Load reflects external deletions in EditorObjects")
	check(store.load_world(world, Enums.InfrDomain.RAIL).ok and rails.get_child_count() == 2, "Rail JSON also loads into EditorObjects")
	var rail: EditorInfrLine3D = rails.get_node("RailTrack_7")
	var expected: Vector3 = rail.to_global(rail.curve.get_point_position(0))
	check(expected.is_equal_approx(Vector3(1, 2, 3)), "Reference load respects transformed containers")
	var rail_edit: EditorInfrLine3D = service.edit_in_cache(rail)
	check(rail_edit.to_global(rail_edit.curve.get_point_position(0)).is_equal_approx(expected), "Rail editing copy preserves world geometry under nonuniform transforms")
	check(rail_edit.to_global(rail_edit.curve.get_point_position(1)).is_equal_approx(rail.to_global(rail.curve.get_point_position(1))), "Editing copy also preserves the far endpoint under scale")
	check((rail_edit.global_basis * rail_edit.curve.get_point_out(0)).is_equal_approx(rail.global_basis * rail.curve.get_point_out(0)), "Editing copy preserves world-space curve handles")
	write_text(rail_path, "{}")
	check(not store.load_world(world, Enums.InfrDomain.RAIL).ok and rail_edit.get_parent() == cache and rail.get_parent() == rails, "Malformed Load preserves both references and unsaved edits")
	check(not store.save_world(world, Enums.InfrDomain.RAIL).ok and rail_edit.get_parent() == cache, "Failed Save retains unsaved cache")
	history.undo.clear_history()
	history.undo.free()
	world.free()
	for name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.get_base_dir()))
	return true

func test_standalone_editorobjects(tree: SceneTree) -> bool:
	var source := WorldEditorObjects.new()
	source.name = "EditorObjects"
	source.map_key = "__editorobjects_json_%d" % OS.get_process_id()
	var directory: String = "res://world/%s/jsondata" % source.map_key
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path: String = directory.path_join("roads.json")
	write_text(path, JSON.stringify([{"num": 15, "points": [{"pos": [1, 2, 3]}, {"pos": [4, 5, 6]}]}]))
	tree.root.add_child(source)
	var infr := Node3D.new()
	infr.name = "EditorInfr"
	source.add_child(infr)
	infr.owner = source
	var roads := GeneratedRoadWays.new()
	roads.name = "EditorRoads"
	infr.add_child(roads)
	roads.owner = source
	var old := Node3D.new()
	old.name = "OldView"
	roads.add_child(old)
	old.owner = source
	var store := Store.new()
	var history := History.new()
	check(store.load_world(source, Enums.InfrDomain.ROAD, history).ok, "JSON loads with EditorObjects as the edited scene root")
	var loaded: EditorInfrLine3D = roads.get_node("RoadWay_15")
	check(loaded.owner == source and not source.has_node("EditorCache"), "Standalone load creates source-owned selectable nodes and no cache")
	var packed := PackedScene.new()
	check(packed.pack(source) == OK, "Generated source view can be saved as a scene")
	var paths: Array[String] = []
	for idx: int in range(packed.get_state().get_node_count()):
		paths.append(str(packed.get_state().get_node_path(idx)).trim_prefix("./"))
	check("EditorInfr/EditorRoads/RoadWay_15" in paths, "Ctrl+S persists the generated line in EditorObjects")
	history.undo.undo()
	check(old.get_parent() == roads and old.owner == source and loaded.get_parent() == null, "Undo restores the previous source view with its ownership")
	history.undo.redo()
	check(loaded.get_parent() == roads and loaded.owner == source, "Redo restores source-owned JSON lines")
	check(store.load_world(source, Enums.InfrDomain.ROAD, history).ok and roads.get_child_count() == 1, "Repeated Inspector loading replaces source lines without duplicates")
	history.undo.undo()
	check(loaded.get_parent() == roads and loaded.owner == source, "Undo of repeated load restores lines after their renderer children rebuild")
	history.undo.clear_history()
	history.undo.free()
	source.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.get_base_dir()))
	return true

func test_cache_upgrade(tree: SceneTree) -> bool:
	var world := WorldMapScene.new()
	tree.root.add_child(world)
	var cache: Node3D = Store.container_for(world, Enums.InfrDomain.ROAD)
	var wrapper := GeneratedRoadWays.new()
	wrapper.name = "EditorRoads"
	cache.add_child(wrapper)
	wrapper.position = Vector3(10, 2, 3)
	var group := Node3D.new()
	group.name = "0__49"
	wrapper.add_child(group)
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRoad(1)
	line.curve = Curve3D.new()
	line.curve.add_point(Vector3.ZERO)
	line.curve.add_point(Vector3.ONE)
	group.add_child(line)
	var before: Vector3 = line.global_position
	Store.container_for(world, Enums.InfrDomain.ROAD)
	check(line.get_parent() == cache and line.owner == world, "Old grouped caches upgrade to flat map-owned lines")
	check(line.global_position.is_equal_approx(before), "Flattening preserves world transforms")
	check(not cache.has_node("EditorRoads"), "Legacy wrapper and number groups are removed from cache")
	world.free()
	return true

func test_runtime_cache(tree: SceneTree) -> bool:
	var map := WorldMapScene.new()
	var cache := Node3D.new()
	cache.name = "EditorCache"
	map.add_child(cache)
	var legacy := Node3D.new()
	legacy.name = "EditorObjects"
	map.add_child(legacy)
	var spawner := MapSpawner.new()
	tree.root.add_child(spawner)
	spawner.register_scene(map)
	check(not map.has_node("EditorCache") and not map.has_node("EditorObjects"), "Runtime removes both authoring containers")
	spawner.free()
	return true

func test_project_json(_tree: SceneTree) -> bool:
	for map: String in ["franzburger", "mpsb", "sachalin", "harzmountains"]:
		for filename: String in ["roads.json", "tracks.json"]:
			var source: Dictionary = Store.read_records("res://world/%s/jsondata/%s" % [map, filename])
			check(source.ok, "Existing %s/%s validates: %s" % [map, filename, source.get("error", "")])
	return true

class History extends RefCounted:
	var undo := UndoRedo.new()
	func create_action(title: String, merge: int, _context: Object) -> void:
		undo.create_action(title, merge)
	func add_do_method(object: Object, method: String, first: Variant, second: Variant = null, third: Variant = null) -> void:
		undo.add_do_method(Callable(object, method).bind(first) if second == null else (Callable(object, method).bind(first, second) if third == null else Callable(object, method).bind(first, second, third)))
	func add_undo_method(object: Object, method: String, first: Variant, second: Variant = null, third: Variant = null) -> void:
		undo.add_undo_method(Callable(object, method).bind(first) if second == null else (Callable(object, method).bind(first, second) if third == null else Callable(object, method).bind(first, second, third)))
	func add_do_property(object: Object, property: String, value: Variant) -> void:
		undo.add_do_property(object, property, value)
	func add_undo_property(object: Object, property: String, value: Variant) -> void:
		undo.add_undo_property(object, property, value)
	func add_do_reference(object: Object) -> void:
		undo.add_do_reference(object)
	func add_undo_reference(object: Object) -> void:
		undo.add_undo_reference(object)
	func commit_action() -> void:
		undo.commit_action()
