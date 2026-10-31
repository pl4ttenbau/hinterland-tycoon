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
	for test: String in ["test_save", "test_load", "test_cache_upgrade", "test_runtime_cache", "test_project_json"]:
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

func test_load(tree: SceneTree) -> bool:
	var world := WorldMapScene.new()
	world.map_key = "__infr_json_test_%d" % OS.get_process_id()
	var directory: String = "res://world/%s/jsondata" % world.map_key
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path: String = directory.path_join("tracks.json")
	write_text(path, JSON.stringify(fixture()))
	tree.root.add_child(world)
	var rails: Node3D = GeneratedRailLines.new()
	world.add_child(rails)
	rails.position = Vector3(10, 5, -3)
	rails.scale = Vector3(2, 3, 4)
	var old: EditorInfrLine3D = EditorInfrLine3D.ofRail(99)
	old.curve = Curve3D.new()
	old.curve.add_point(Vector3.ZERO)
	old.curve.add_point(Vector3.ONE)
	rails.add_child(old)
	old.owner = world
	var roads: Node3D = GeneratedRoadWays.new()
	world.add_child(roads)
	var road_path: String = directory.path_join("roads.json")
	var road_data: Array = [{"num": 51, "name": "Road", "type": "dirt_path", "points": [{"pos": [0, 1, 0]}, {"pos": [7, 2, 3]}]}]
	write_text(road_path, JSON.stringify(road_data))
	var store := Store.new()
	var history := History.new()
	check(store.load_world(world, Enums.InfrDomain.ROAD, history).ok, "Road load creates cache")
	roads = world.get_node("EditorCache")
	check(roads.has_node("RoadWay_51"), "Road load places lines directly under cache")
	check(roads.owner == world and roads.get_node("RoadWay_51").owner == world, "Cache and line belong to map")
	history.undo.undo()
	check(Store.domain_roots(roads, Enums.InfrDomain.ROAD).is_empty(), "Undo removes loaded roads")
	history.undo.redo()
	check(store.save_world(world, Enums.InfrDomain.ROAD).ok, "Loaded roads save back to JSON")
	check(Store.read_records(road_path).records[0].type == "dirt_path", "Road types survive load and save")
	check(store.load_world(world, Enums.InfrDomain.RAIL, history).ok, "Load builds rails from JSON")
	rails = world.get_node("EditorCache")
	check(Store.domain_roots(rails, Enums.InfrDomain.RAIL).size() == 2 and old.get_parent() == null, "Load replaces existing children without duplicates")
	var loaded: EditorInfrLine3D = rails.get_node("RailTrack_7")
	check(loaded.owner == world and loaded.to_global(loaded.curve.get_point_position(0)).is_equal_approx(Vector3(1, 2, 3)), "Load preserves ownership and world position under transformed containers")
	history.undo.undo()
	check(old.get_parent() == rails and old.owner == world, "Undo restores old content and its scene ownership")
	history.undo.redo()
	check(Store.domain_roots(rails, Enums.InfrDomain.RAIL).size() == 2 and loaded.get_parent() == rails, "Redo restores loaded content")
	check(store.load_world(world, Enums.InfrDomain.RAIL, history).ok and Store.domain_roots(rails, Enums.InfrDomain.RAIL).size() == 2, "Repeated loading does not duplicate rails")
	# Remove a previously loaded record: saving now intentionally deletes it.
	var removed: Node = rails.get_node("RailTrack_8")
	rails.remove_child(removed)
	var saved: Dictionary = store.save_world(world, Enums.InfrDomain.RAIL)
	check(saved.ok and Store.read_records(path).records.size() == 1, "Save reflects deletion of a record that was explicitly loaded")
	var managed: EditorInfrLine3D = rails.get_node("RailTrack_7")
	check(Store.next_number(world, Enums.InfrDomain.RAIL) == 8, "New IDs account for JSON records")
	check(Store.read_records(path).records[0].type == "750_MM", "Load/save retains rail gauge")
	# Restore before clearing history, whose node references own detached records.
	rails.add_child(removed)
	store.flush_saved(world, Enums.InfrDomain.RAIL, history)
	check(Store.domain_roots(rails, Enums.InfrDomain.RAIL).is_empty(), "Successful save can flush visible rails")
	check(roads.has_node("RoadWay_51"), "Flushing rails preserves road cache")
	check(store.save_world(world, Enums.InfrDomain.RAIL).ok and Store.read_records(path).records.size() == 1, "Repeated Save after flushing cannot erase saved records")
	history.undo.undo()
	check(managed.get_parent() == rails and managed.owner == world, "Undo restores flushed cache with map ownership")
	history.undo.redo()
	check(Store.domain_roots(rails, Enums.InfrDomain.RAIL).is_empty(), "Redo flushes the saved domain again")
	check(store.load_world(world, Enums.InfrDomain.RAIL, history).ok and rails.has_node("RailTrack_7"), "Load restores the saved geometry after flushing")
	managed = rails.get_node("RailTrack_7")
	write_text(path, "{}")
	check(not store.load_world(world, Enums.InfrDomain.RAIL, history).ok and managed.get_parent() == rails, "Malformed load leaves editor objects untouched")
	check(not store.save_world(world, Enums.InfrDomain.RAIL).ok and managed.get_parent() == rails, "Failed Save retains visible unsaved cache")
	history.undo.clear_history()
	history.undo.free()
	world.free()
	for name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(name))
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
	func add_do_method(object: Object, method: String, first: Variant, second: Variant, third: Variant = null) -> void:
		undo.add_do_method(Callable(object, method).bind(first, second) if third == null else Callable(object, method).bind(first, second, third))
	func add_undo_method(object: Object, method: String, first: Variant, second: Variant, third: Variant = null) -> void:
		undo.add_undo_method(Callable(object, method).bind(first, second) if third == null else Callable(object, method).bind(first, second, third))
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
