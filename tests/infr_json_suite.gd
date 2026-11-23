## Regression checks for infrastructure JSON persistence, scene ownership and undo.
class_name InfrJsonSuite extends RefCounted

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
	for test: String in ["test_save", "test_rail_forks_on_save", "test_stops_follow_point_changes", "test_stops_on_road_saves", "test_stop_catalog_problems", "test_stop_anchors", "test_interchanges_text", "test_formatting", "test_load", "test_standalone_editorobjects", "test_cache_upgrade", "test_runtime_cache", "test_project_json"]:
		check(call(test, tree) == true, test + " completed")
	print("Infrastructure JSON tests: %d checks, %d failures" % [checks, failures])
	return 1 if failures else 0

func fixture() -> Array:
	return [{"num": 7, "name": "Original", "type": "750_MM", "tag": "keep", "hideBed": true,
		"extension": {"keep": 4}, "points": [
			{"pos": [1, 2, 3], "fork": {"connectiveTracks": [8]}, "custom": "keep"},
			{"pos": [8, 3, 4], "station": {"name": "keep"}}
			## Track 8 runs straight into the start of the saved line 7 (world (10, 5, -3), see make_line), so the
			## fork 7 -> 8 is what the geometry calls for and survives the fork regeneration on save.
		]}, {"num": 8, "name": "Unseen", "type": "750_MM", "points": [{"pos": [4, 5, -3]}, {"pos": [10, 5, -3]}]}]

func make_line(tree: SceneTree) -> EditorInfrLine3D:
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRail(7, "Edited")
	tree.root.add_child(line)
	line.position = Vector3(10, 5, -3)
	line.scale = Vector3(2, 3, 4)
	line.curve = Curve3D.new()
	line.curve.add_point(Vector3.ZERO, Vector3.ZERO, Vector3(1, 2, 3))
	line.curve.add_point(Vector3(4, 1, 0), Vector3(-2, -1, 0))
	return line

## Rail saves regenerate forks from the geometry, and a fork that only lists tracks no longer blocks
## changing a track's point count: it is rebuilt on the new end instead.
func test_rail_forks_on_save(tree: SceneTree) -> bool:
	var directory: String = "/tmp/hinterland-forks-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("tracks.json")
	## Track 1 ends at (10, 0, 0) with a fork to track 2, which continues straight on from there.
	write_text(path, JSON.stringify([
		{"num": 1, "name": "One", "type": "750_MM", "points": [{"pos": [0, 0, 0]},
			{"pos": [10, 0, 0], "fork": {"connectiveTracks": [2]}}]},
		{"num": 2, "name": "Two", "type": "750_MM", "points": [{"pos": [10, 0, 0]}, {"pos": [20, 0, 0]}]},
	]) + "\n")
	var store: InfrJsonStore = InfrJsonStore.new()
	## The editor adds a middle point to track 1: three points now, the fork's old index is a middle point.
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRail(1, "One")
	tree.root.add_child(line)
	line.curve = Curve3D.new()
	for x: float in [0.0, 5.0, 10.0]:
		line.curve.add_point(Vector3(x, 0, 0))
	var lines: Array[EditorInfrLine3D] = [line]
	check(store.save_lines(path, lines, Enums.InfrDomain.RAIL).ok, "A generated fork does not block a changed point count")
	var data: Array = InfrJsonStore.read_records(path).records
	check(not data[0].points[1].has("fork"), "The fork does not stay on what is now a middle point")
	check(data[0].points[2].fork.connectiveTracks.map(func(n: Variant) -> int: return int(n)) == [2], "The fork is rebuilt on the new end")
	check(data[1].points[0].fork.connectiveTracks.map(func(n: Variant) -> int: return int(n)) == [1], "The track it meets gets its fork too")
	check(not data[0].points[0].has("fork") and not data[1].points[1].has("fork"), "Open ends get no fork")
	## A fork with more than its track list is hand-made meaning and still blocks.
	var records: Array = InfrJsonStore.read_records(path).records
	records[0].points[2].fork["static"] = true
	write_text(path, JSON.stringify(records) + "\n")
	line.curve.add_point(Vector3(15, 0, 0))
	check(not store.save_lines(path, lines, Enums.InfrDomain.RAIL).ok, "A fork with extra keys still blocks a changed point count")
	line.queue_free()
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	return true

## Stops name a node by index. Adding a point before them must not make them jump to another node: the
## save moves them back to where they stood, in interchanges.json next to tracks.json.
func test_stops_follow_point_changes(tree: SceneTree) -> bool:
	var directory: String = "/tmp/hinterland-stops-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("tracks.json")
	var catalog_path: String = directory.path_join("interchanges.json")
	## A straight track along +x: curve distance == x.
	write_text(path, JSON.stringify([{"num": 1, "name": "Line", "type": "750_MM",
		"points": [{"pos": [0, 0, 0]}, {"pos": [10, 0, 0]}, {"pos": [20, 0, 0]}]}]) + "\n")
	## Stop 1 stands 4 m past node 1 (x = 14), stop 2 on the last node (x = 20).
	write_text(catalog_path, JSON.stringify([{"num": 1, "name": "Halt", "townNum": 1, "stops": [
		{"num": 1, "domain": "RAIL", "trackNum": 1, "nodeIndex": 1, "nodeOffset": 4},
		{"num": 2, "domain": "RAIL", "trackNum": 1, "nodeIndex": 2}]}], "\t", false) + "\n")
	var store: InfrJsonStore = InfrJsonStore.new()
	## The editor inserts a point at x = 5: every later node index moves up by one.
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRail(1, "Line")
	tree.root.add_child(line)
	line.curve = Curve3D.new()
	for x: float in [0.0, 5.0, 10.0, 20.0]:
		line.curve.add_point(Vector3(x, 0, 0))
	var lines: Array[EditorInfrLine3D] = [line]
	check(store.save_lines(path, lines, Enums.InfrDomain.RAIL).ok, "Adding a point to a track with stops saves")
	var text: String = FileAccess.get_file_as_string(catalog_path)
	var stops: Array = JSON.parse_string(text)[0].stops
	check(int(stops[0].nodeIndex) == 2 and absf(float(stops[0].get("nodeOffset", 0.0)) - 4.0) < 0.05,
		"A stop between nodes keeps its place, now counted from the shifted node")
	check(int(stops[1].nodeIndex) == 3 and not stops[1].has("nodeOffset"), "A stop on the last node follows it to its new index")
	check(text.contains('"num": 1,') and text.contains('"trackNum": 1,') and not text.contains("1.0"),
		"interchanges.json keeps integers as integers")
	## Moving points without changing their count leaves the anchors alone: node + offset follows the geometry.
	var before: String = text
	line.curve.set_point_position(3, Vector3(25, 0, 0))
	check(store.save_lines(path, lines, Enums.InfrDomain.RAIL).ok and FileAccess.get_file_as_string(catalog_path) == before,
		"Saves that keep the point count do not touch interchanges.json")
	line.queue_free()
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	return true

## Removes a test directory and everything in it (backups included).
func remove_directory(directory: String) -> void:
	for file: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)

## A straight line of the given domain along +x (curve distance == x), as the editor would save it.
func straight_line(tree: SceneTree, domain: Enums.InfrDomain, num: int, xs: Array) -> EditorInfrLine3D:
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRail(num, "Line") if domain == Enums.InfrDomain.RAIL \
		else EditorInfrLine3D.ofRoad(num, "Road", false)
	tree.root.add_child(line)
	line.curve = Curve3D.new()
	for x: float in xs:
		line.curve.add_point(Vector3(x, 0, 0))
	return line

## Road saves re-anchor road stops the same way, and leave rail stops alone even when a track has the
## same number as the edited road: the two domains number their lines independently.
func test_stops_on_road_saves(tree: SceneTree) -> bool:
	var directory: String = "/tmp/hinterland-road-stops-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("roads.json")
	var catalog_path: String = directory.path_join("interchanges.json")
	write_text(path, JSON.stringify([{"num": 3, "name": "Road", "type": InfrDomains.default_type(Enums.InfrDomain.ROAD),
		"autosmooth": false, "points": [{"pos": [0, 0, 0]}, {"pos": [10, 0, 0]}, {"pos": [20, 0, 0]}, {"pos": [30, 0, 0]}]}]) + "\n")
	## The bus stop stands 2 m past node 2 (x = 22); the rail stop names track 3, not road 3.
	write_text(catalog_path, JSON.stringify([{"num": 1, "name": "Square", "townNum": 1, "stops": [
		{"num": 1, "domain": "ROAD", "roadNum": 3, "nodeIndex": 2, "nodeOffset": 2, "roadStopDirection": "BOTH_DIRECTIONS"},
		{"num": 2, "domain": "RAIL", "trackNum": 3, "nodeIndex": 2}]}], "\t", false) + "\n")
	## The editor removes the point at x = 10: node 2 (x = 20) becomes node 1.
	var line: EditorInfrLine3D = straight_line(tree, Enums.InfrDomain.ROAD, 3, [0.0, 20.0, 30.0])
	var lines: Array[EditorInfrLine3D] = [line]
	check(store_save(path, lines, Enums.InfrDomain.ROAD), "Removing a point from a road with a stop saves")
	var stops: Array = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))[0].stops
	check(int(stops[0].nodeIndex) == 1 and absf(float(stops[0].get("nodeOffset", 0.0)) - 2.0) < 0.05,
		"The bus stop keeps its place, now counted from the node that moved down")
	check(stops[0].roadStopDirection == "BOTH_DIRECTIONS", "Other stop fields survive the re-anchoring")
	check(int(stops[1].nodeIndex) == 2, "A rail stop on the track with the road's number is not touched")
	line.queue_free()
	remove_directory(directory)
	return true

func store_save(path: String, lines: Array[EditorInfrLine3D], domain: Enums.InfrDomain) -> bool:
	return InfrJsonStore.new().save_lines(path, lines, domain).ok

## The stop catalog only matters when a point count changes; then a broken catalog blocks the save, so
## the line file and its stops can never disagree. Without a catalog there is nothing to re-anchor.
func test_stop_catalog_problems(tree: SceneTree) -> bool:
	var directory: String = "/tmp/hinterland-stop-catalog-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("tracks.json")
	var catalog_path: String = directory.path_join("interchanges.json")
	var original: String = JSON.stringify([{"num": 1, "name": "Line", "type": "750_MM",
		"points": [{"pos": [0, 0, 0]}, {"pos": [10, 0, 0]}, {"pos": [20, 0, 0]}]}]) + "\n"
	write_text(path, original)
	var line: EditorInfrLine3D = straight_line(tree, Enums.InfrDomain.RAIL, 1, [0.0, 5.0, 10.0, 20.0])
	var lines: Array[EditorInfrLine3D] = [line]
	write_text(catalog_path, "{broken")
	check(not store_save(path, lines, Enums.InfrDomain.RAIL) and FileAccess.get_file_as_string(path) == original,
		"A broken stop catalog blocks a save that changes a point count, and the track file stays as it was")
	check(FileAccess.get_file_as_string(catalog_path) == "{broken", "The broken catalog itself is not overwritten")
	## Same point count as the saved track: the catalog is not needed, so it does not block.
	var same_count: EditorInfrLine3D = straight_line(tree, Enums.InfrDomain.RAIL, 1, [0.0, 10.0, 25.0])
	var unchanged: Array[EditorInfrLine3D] = [same_count]
	check(store_save(path, unchanged, Enums.InfrDomain.RAIL), "A broken catalog does not block saves that keep the point count")
	DirAccess.remove_absolute(catalog_path)
	check(store_save(path, lines, Enums.InfrDomain.RAIL) and not FileAccess.file_exists(catalog_path),
		"Without a stop catalog, point count changes save and no catalog is created")
	line.queue_free()
	same_count.queue_free()
	remove_directory(directory)
	return true

## EditorStopAnchors on plain records, without any files: positions for labels and the re-anchoring rules.
func test_stop_anchors(_tree: SceneTree) -> bool:
	var track: Callable = func(num: int, xs: Array) -> Dictionary:
		var points: Array = []
		for x: float in xs:
			points.append({"pos": [x, 0, 0]})
		return {"num": num, "name": "T%d" % num, "type": "750_MM", "points": points}
	var lines := EditorStopAnchors.LineCache.new({"RAIL": {1: track.call(1, [0, 10, 20])}, "ROAD": {}})
	var position: Vector3 = EditorStopAnchors.stop_position(
		{"domain": "RAIL", "trackNum": 1, "nodeIndex": 1, "nodeOffset": -2.0}, lines)
	check(position.distance_to(Vector3(8, 0, 0)) < 0.05, "A label stands at node + offset (2 m before node 1)")
	check(EditorStopAnchors.stop_position({"domain": "RAIL", "trackNum": 1, "nodeIndex": 2}, lines) == Vector3(20, 0, 0),
		"A label on a node stands exactly on it")
	for bad: Dictionary in [{"domain": "RAIL", "trackNum": 1, "nodeIndex": 9}, {"domain": "RAIL", "trackNum": 5, "nodeIndex": 0},
			{"domain": "RAIL", "trackNum": 1}, {"domain": "ROAD", "roadNum": 1, "nodeIndex": 0}]:
		check(EditorStopAnchors.stop_position(bad, lines) == Vector3.INF, "A stop that cannot be placed has no position: %s" % str(bad))
	check(lines.get_line("RAIL", 1) == lines.get_line("RAIL", 1), "The cache builds each line once")

	## Track 1 loses its point at x = 10; track 2 keeps its point count but changes its geometry.
	var old_records: Dictionary = {1: track.call(1, [0, 10, 20, 30]), 2: track.call(2, [0, 10])}
	var new_records: Dictionary = {1: track.call(1, [0, 20, 30]), 2: track.call(2, [0, 50])}
	var catalog: Array = [{"num": 1, "stops": [
		{"num": 1, "domain": "RAIL", "trackNum": 1, "nodeIndex": 2, "nodeOffset": 3.0},
		{"num": 2, "domain": "RAIL", "trackNum": 1, "nodeIndex": 1, "nodeOffset": 1.0},
		{"num": 3, "domain": "RAIL", "trackNum": 2, "nodeIndex": 1},
		{"num": 4, "domain": "ROAD", "roadNum": 1, "nodeIndex": 2}]}]
	var report: Array[String] = EditorStopAnchors.reanchor_stops(catalog, "RAIL", old_records, new_records)
	var stops: Array = catalog[0].stops
	## x = 23 on the new curve: 3 m past node 1 (x = 20), nearer than node 2 (x = 30).
	check(int(stops[0].nodeIndex) == 1 and absf(stops[0].nodeOffset - 3.0) < 0.05, "A stop after the removed point keeps its place")
	## x = 11 stood next to the removed node; now node 0 (x = 0) and node 1 (x = 20) are both further away.
	check(int(stops[1].nodeIndex) == 1 and absf(stops[1].nodeOffset + 9.0) < 0.05,
		"A stop at a removed node stays where it was, anchored to the nearest remaining node")
	check(int(stops[2].nodeIndex) == 1 and not stops[2].has("nodeOffset"), "Stops on lines with an unchanged point count are not touched")
	check(int(stops[3].nodeIndex) == 2, "Stops of the other domain are not touched")
	check(report.size() == 2 and report[0].begins_with("Stop 1 on "), "Each moved stop is reported once: %s" % str(report))
	check(EditorStopAnchors.reanchor_stops(catalog, "RAIL", new_records, new_records).is_empty(), "Nothing to do reports nothing")
	return true

## interchanges.json is written through JSON.stringify, which knows no integers once the file was parsed.
func test_interchanges_text(_tree: SceneTree) -> bool:
	var parsed: Array = JSON.parse_string('[{"num": 3, "name": "Halt", "townNum": 2, "stops": [' \
		+ '{"num": 1, "domain": "RAIL", "trackNum": 4, "nodeIndex": 2, "nodeOffset": 4.5}]}]')
	var text: String = InfrJsonFormatter.interchanges_text(parsed)
	check(text.contains('"num": 3,') and text.contains('"townNum": 2,') and text.contains('"nodeIndex": 2,'),
		"Whole numbers read back from JSON are written as integers")
	check(text.contains('"nodeOffset": 4.5'), "Fractions such as offsets stay as they are")
	check(text.find('"num"') < text.find('"name"') and text.find('"name"') < text.find('"townNum"') \
		and text.find('"townNum"') < text.find('"stops"'), "Keys keep their order instead of being sorted")
	check(text.ends_with("}\n]\n") and text.contains('\n\t{\n\t\t"num"'), "Tab indentation and a final newline, like the existing files")
	check(JSON.parse_string(text) == parsed, "The text reads back as the same records")
	return true


func test_save(tree: SceneTree) -> bool:
	var directory: String = "/tmp/hinterland-json-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory.path_join("tracks.json")
	var original: String = JSON.stringify(fixture()) + "\n"
	write_text(path, original)
	var store: InfrJsonStore = InfrJsonStore.new()
	var line: EditorInfrLine3D = make_line(tree)
	var lines: Array[EditorInfrLine3D] = [line]
	var saved: EditorActionResult = store.save_lines(path, lines, Enums.InfrDomain.RAIL)
	check(saved.ok, "Save succeeds")
	check(FileAccess.get_file_as_string(saved.backup) == original, "Backup preserves the exact original bytes")
	var data: Array = InfrJsonStore.read_records(path).records
	check(data.size() == 2 and data[1].num == 8, "Saving a partial editor scene retains unseen JSON records")
	check(data[0].type == "750_MM" and data[0].tag == "keep" and data[0].hideBed and data[0].extension.keep == 4, "Top-level metadata and actual type survive")
	check(data[0].name == "Edited" and data[0].num == 7, "Actual ID and edited name are saved")
	check(int(data[0].points[0].fork.connectiveTracks[0]) == 8 and data[0].points[1].station.name == "keep", "Fork/station metadata survives")
	check(WorldUtils.vec3_from_float_arr(data[0].points[1].pos) == Vector3(18, 8, -3), "Positions are saved in world coordinates")
	check(WorldUtils.vec3_from_float_arr(data[0].points[0].handleOut) == Vector3(2, 6, 12), "Handle offsets include parent scale without translation")
	line.rail_gauge = InfrType.GAUGE_1000_MM
	var again: EditorActionResult = store.save_lines(path, lines, Enums.InfrDomain.RAIL)
	check(again.ok and again.backup != saved.backup and FileAccess.file_exists(again.backup), "Each save makes a fresh backup")
	check(not FileAccess.file_exists(saved.backup), "Older backups of the file are removed, keeping only the newest")
	check(InfrJsonStore.read_records(path).records[0].type == InfrType.GAUGE_1000_MM, "A track gauge selected in the editor is saved")
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
	check(not InfrJsonStore.write_with_backup(blocked, fixture()).ok and DirAccess.dir_exists_absolute(blocked), "Failed replacement leaves the original destination intact")
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
	var text: String = InfrJsonStore.format_json(data)
	check(text.contains('"pos": [2.39, 2.40, 0.00]'), "Positions round normally with exactly two decimals")
	check(text.contains('"pos": [-1.24, 100.00, 4.00]'), "Negative values and trailing zeros are formatted correctly")
	check(text.contains('"pos": [-655.13, 1.13, 0.01]'), "Halfway values use normal rounding away from zero")
	check(text.contains('"short": [1, 2, 3]'), "Short numeric arrays stay on one line")
	check(text.contains('"long": [\n'), "Arrays exceeding line width put each value on its own line")
	var parsed: Array = JSON.parse_string(text)
	check(is_equal_approx(parsed[0].points[0].handleOut[0], 1.235), "Handles keep millimetre precision, finer than positions")
	check(text.contains('"handleOut": [1.235, 0.0, 3.0]'), "Handles are written with 3 decimals and no float noise")
	check(parsed[0].note == "literal [1, 2, 3]", "Formatting preserves strings containing array-like text")
	## Track and road number lists as JSON parsing returns them (floats) and as generators build them (ints).
	var links: String = InfrJsonStore.format_json({"fork": {"connectiveTracks": [4.0, 92]},
		"cross": {"connectiveRoads": [7.0], "autoConnectiveRoads": [3.0, 5]}})
	check(links.contains('"connectiveTracks": [4, 92]') and links.contains('"connectiveRoads": [7]') \
		and links.contains('"autoConnectiveRoads": [3, 5]'), "Track and road number lists are always written as integers")
	for line: String in text.split("\n"):
		check(line.replace("\t", "    ").length() <= InfrJsonStore.JSON_LINE_WIDTH, "Numeric array layout respects the line width")
	InfrJsonStore.round_positions(data)
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
	var cache: Node3D = InfrJsonStore.container_for(world, Enums.InfrDomain.ROAD)
	cache.show()
	var unsaved: EditorInfrLine3D = EditorInfrLine3D.ofRoad(70, "Unsaved")
	unsaved.curve = Curve3D.new()
	unsaved.curve.add_point(Vector3(100, 1, 0))
	unsaved.curve.add_point(Vector3(110, 2, 3))
	cache.add_child(unsaved)
	unsaved.owner = world
	var store := InfrJsonStore.new()
	var history := History.new()
	var service: Node = RoadEndpointConnection.ensure(world)
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
	var saved: EditorActionResult = store.save_world(world, Enums.InfrDomain.ROAD)
	check(saved.ok and saved.count == 2, "Save merges hidden cached edits and new roads")
	var data: Array = InfrJsonStore.read_records(road_path).records
	check(data[0].type == "dirt_path", "Editing an existing road preserves its saved type")
	check(WorldUtils.vec3_from_float_arr(data[0].points[1].pos) == Vector3(8, 3, 4), "Saved JSON contains working-copy geometry")
	check(store.load_world(world, Enums.InfrDomain.ROAD).ok, "Successful Save can refresh the reference view")
	store.flush_saved(world, Enums.InfrDomain.ROAD, history)
	check(InfrJsonStore.domain_roots(cache, Enums.InfrDomain.ROAD).is_empty(), "Only unsaved working copies are flushed")
	check(roads.get_child_count() == 2 and roads.get_node("RoadWay_51").visible, "Saved roads remain visible in EditorObjects after flushing")
	check(store.save_world(world, Enums.InfrDomain.ROAD).ok and InfrJsonStore.read_records(road_path).records.size() == 2, "Saving an empty cache preserves saved roads")
	# An external JSON deletion must not be resurrected from stale reference nodes.
	write_text(road_path, JSON.stringify([data[0]]))
	check(store.save_world(world, Enums.InfrDomain.ROAD).ok and InfrJsonStore.read_records(road_path).records.size() == 1, "Reference geometry cannot write back an externally deleted road")
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
	var store := InfrJsonStore.new()
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
	var cache: Node3D = InfrJsonStore.container_for(world, Enums.InfrDomain.ROAD)
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
	InfrJsonStore.container_for(world, Enums.InfrDomain.ROAD)
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
			var source: InfrCatalogReadResult = InfrJsonStore.read_records("res://world/%s/jsondata/%s" % [map, filename])
			check(source.ok, "Existing %s/%s validates: %s" % [map, filename, source.error])
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
