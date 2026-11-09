## godot --headless --path . --script res://tests/gps_cursor_test.gd -- --no-mcp
extends Node

class FixtureCursor:
	extends WorldCursor3D
	var metadata: MapSizeAndPosData
	var terrain_fixture: Terrain3D
	func get_map_size_pos_dto_in_editor(_report_missing: bool = true) -> MapSizeAndPosData:
		return metadata
	func get_editor_terrain(_report_missing: bool = true) -> Terrain3D:
		return terrain_fixture

var failures: int = 0
var checks: int = 0

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	get_tree().create_timer(30.0).timeout.connect(func() -> void: get_tree().quit(1))
	for method: String in ["test_conversion", "test_input", "test_cursor", "test_world_lookup"]:
		check(call(method) == true, method + " completes without a runtime error")
	print("GPS cursor tests: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)

func test_conversion() -> bool:
	var map := MapSizeAndPosData.of_dict({
		"longLat": {"topLeft": [54.0, 18.0], "bottomRight": [53.0, 20.0]},
		"rasterSize": [5, 3], "rasterOffset": [-2, 7]})
	check(WorldUtils.gps_coords_to_map_pos([54.0, 18.0], map) == Vector2(-2, 7), "NW is the raster offset")
	check(WorldUtils.gps_coords_to_map_pos([53.0, 20.0], map) == Vector2(2, 9), "SE is last sample, not one sample beyond")
	check(WorldUtils.gps_coords_to_map_pos([54.0, 20.0], map) == Vector2(2, 7), "East changes X only")
	check(WorldUtils.gps_coords_to_map_pos([53.0, 18.0], map) == Vector2(-2, 9), "South changes Z only")
	check(WorldUtils.gps_coords_to_map_pos([53.75, 18.25], map) == Vector2(-1.5, 7.5), "Fractional placement is retained on a rectangular raster")
	check(not WorldUtils.gps_coords_to_map_pos([54.1, 18.0], map).is_finite(), "Out-of-map positions fail instead of clamping")
	check(not WorldUtils.gps_coords_to_map_pos([], map).is_finite(), "Missing coordinates fail")
	check(not WorldUtils.gps_coords_to_map_pos([53.5, 19.0], null).is_finite(), "Missing map fails")
	var spacing := 1.3
	check(WorldUtils.world_pos_to_gps_coords(Vector2(-2, 7) * spacing, spacing, map) == [54.0, 18.0], "Inverse accepts the rounded northwest world position")
	check(WorldUtils.world_pos_to_gps_coords(Vector2(2, 9) * spacing, spacing, map) == [53.0, 20.0], "Inverse accepts the rounded southeast world position")
	var fractional: Array[float] = WorldUtils.world_pos_to_gps_coords(Vector2(-1.5, 7.5) * spacing, spacing, map)
	check(fractional.size() == 2 and is_equal_approx(fractional[0], 53.75) and is_equal_approx(fractional[1], 18.25), "Inverse keeps fractional position, raster offset and spacing")
	check(WorldUtils.world_pos_to_gps_coords(Vector2(3, 9) * spacing, spacing, map).is_empty(), "Inverse rejects positions outside the map")
	check(WorldUtils.world_pos_to_gps_coords(Vector2.ZERO, 0.0, map).is_empty(), "Inverse rejects zero spacing")
	map.long_lat.bottomRight[0] = 54.0
	check(not WorldUtils.gps_coords_to_map_pos([54.0, 19.0], map).is_finite(), "Zero-height GPS extent fails")
	check(WorldUtils.world_pos_to_gps_coords(Vector2(0, 8), 1.0, map).is_empty(), "Inverse rejects degenerate metadata")
	var gdansk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://world/gdansk/jsondata/mapinfo.json"))
	var actual := MapSizeAndPosData.of_dict(gdansk["sizeAndPos"])
	var actual_offset := Vector2(actual.raster_offset[0], actual.raster_offset[1])
	check(WorldUtils.gps_coords_to_map_pos([54.37, 18.66], actual) == actual_offset, "Gdansk NW")
	check(WorldUtils.gps_coords_to_map_pos([54.0465, 19.213], actual) == actual_offset + Vector2(3599, 3599), "Gdansk SE")
	var town := WorldUtils.gps_coords_to_map_pos([54.2146299, 19.1150846], actual)
	check(town.distance_to(actual_offset + Vector2(2961.75312, 1728.52238)) < 0.02, "Nowy Dwor GPS matches the heightmap sample grid")
	var origin_coords: Array[float] = WorldUtils.world_pos_to_gps_coords(Vector2.ZERO, 1.0, actual)
	check(origin_coords.size() == 2 and "%.6f, %.6f" % origin_coords == "54.208205, 18.936577", "Gdansk cursor at the saved world origin")
	return true

func test_input() -> bool:
	check(WorldUtils.gps_coords_str_to_float_arr(" 54.21463, 19.11508 ") == [54.21463, 19.11508], "Decimal coordinates parse with whitespace")
	check(WorldUtils.gps_coords_str_to_float_arr("-12.5, -45.25") == [-12.5, -45.25], "Signed decimal coordinates parse")
	for value: String in ["", "54.2", "54.2,", "hello,19", "54,19,1", "91,19", "54,181", "NaN,19", "54,inf"]:
		check(WorldUtils.gps_coords_str_to_float_arr(value).is_empty(), "Reject invalid GPS: " + value)
	return true

func test_cursor() -> bool:
	var terrain := Terrain3D.new()
	terrain.vertex_spacing = 10.0
	get_tree().root.add_child(terrain)
	var image := Image.create(256, 256, false, Image.FORMAT_RF)
	image.fill(Color(-3.5, 0, 0, 1))
	terrain.data.import_images([image, null, null], Vector3.ZERO, 0.0, 1.0)
	var parent := Node3D.new()
	get_tree().root.add_child(parent)
	parent.position = Vector3(100, 12, -200)
	var cursor := FixtureCursor.new()
	parent.add_child(cursor)
	var current_gps_usage: int = 0
	for property: Dictionary in cursor.get_property_list():
		if property.name == "gps_current_gps":
			current_gps_usage = property.usage
			break
	var expected_usage: int = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
	var usage_mask: int = expected_usage | PROPERTY_USAGE_STORAGE
	check((current_gps_usage & usage_mask) == expected_usage, "Current GPS is read-only in the Inspector and not stored (usage %d)" % current_gps_usage)
	cursor.terrain_fixture = terrain
	cursor.metadata = MapSizeAndPosData.of_dict({
		"longLat": {"topLeft": [54.0, 18.0], "bottomRight": [53.0, 20.0]},
		"rasterSize": [5, 3], "rasterOffset": [2, 3]})
	var previous_world: WorldMapScene = GlobalState.world_container
	GlobalState.world_container = null
	cursor.gps_coords = "53.5,19"
	cursor.do_apply_gps_coords_pos()
	check(cursor.global_position.is_equal_approx(Vector3(40, -3.5, 40)), "Editor cursor uses terrain height, spacing and global position without runtime world")
	check(cursor.gps_current_gps == "53.500000, 19.000000", "Current GPS reverses placement through a transformed parent")
	cursor.global_position.y = 100.0
	check(cursor.gps_current_gps == "53.500000, 19.000000", "Height does not affect current GPS")
	cursor._do_put_on_ground()
	check(is_equal_approx(cursor.global_position.y, -3.5), "Put On Ground accepts negative elevations")
	var unchanged: Vector3 = cursor.global_position
	cursor.gps_coords = "invalid"
	cursor.do_apply_gps_coords_pos()
	check(cursor.global_position == unchanged, "Bad text never teleports the cursor")
	cursor.global_position.x = 50.0
	check(cursor.gps_current_gps == "53.500000, 19.500000", "Moving the marker refreshes GPS independently of the input")
	cursor.global_position.z = 60.0
	check(cursor.gps_current_gps == "Outside map bounds", "Cursor reports positions outside the GPS rectangle")
	cursor.global_position = unchanged
	cursor.gps_coords = "53.5,19"
	cursor.metadata = null
	check(cursor.gps_current_gps == "GPS unavailable", "Cursor reports missing map metadata")
	cursor.do_apply_gps_coords_pos()
	check(cursor.global_position == unchanged, "Missing metadata never teleports the cursor")
	cursor.metadata = MapSizeAndPosData.of_dict({
		"longLat": {"topLeft": [54.0, 18.0], "bottomRight": [53.0, 20.0]},
		"rasterSize": [5, 3], "rasterOffset": [5000, 5000]})
	cursor.do_apply_gps_coords_pos()
	check(cursor.global_position == unchanged, "Missing terrain height never teleports the cursor")
	GlobalState.world_container = previous_world
	parent.free()
	terrain.free()
	return true

func test_world_lookup() -> bool:
	var world := WorldMapScene.new()
	world.map_key = "gdansk"
	var nested := Node3D.new()
	world.add_child(nested)
	var cursor := WorldCursor3D.new()
	nested.add_child(cursor)
	var terrain := Terrain3D.new()
	terrain.name = "TerrainWithCustomName"
	nested.add_child(terrain)
	world.terrain = terrain
	check(cursor.get_editor_terrain() == terrain, "Exported world terrain is preferred")
	world.terrain = null
	check(cursor.get_editor_terrain() == terrain, "Nested, unowned terrain with a custom name is found")
	var metadata := cursor.get_map_size_pos_dto_in_editor()
	check(metadata != null and metadata.raster_size == [3600, 3600], "Owning world provides GPS metadata")
	world.map_key = "nonexistent_gps_test_map"
	check(cursor.get_map_size_pos_dto_in_editor() == null, "Missing map returns null safely")
	world.free()
	return true
