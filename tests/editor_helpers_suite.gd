extends RefCounted
## Shared editor helpers: the InfrDomains table, EditorCache.find, WorldUtils.owning_map, and which
## EditorInfrLine3D properties are kept out of saved scenes.

var failures: int = 0
var root: Window

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

## Loaded by editor_helpers_test.gd once autoloads exist; returns the exit code.
func run(scene_tree: SceneTree) -> int:
	root = scene_tree.root
	for test: Callable in [test_infr_domains, test_cache_lookup, test_owning_map, test_line_storage]:
		check(test.call() == true, "%s completed without runtime errors" % test.get_method())
	print("Editor helper tests: %d failures" % failures)
	return 1 if failures > 0 else 0

func test_infr_domains() -> bool:
	var rail: Enums.InfrDomain = Enums.InfrDomain.RAIL
	var road: Enums.InfrDomain = Enums.InfrDomain.ROAD
	## File names are what the loaders and the JSON store read; changing them would orphan every map.
	check(InfrDomains.json_stem(rail) == "tracks" and InfrDomains.json_stem(road) == "roads", "Catalog file stems match the map JSON files")
	## The JSON key must stay the enum's name: interchanges.json and stop labels store it as text.
	for domain: Enums.InfrDomain in [rail, road]:
		check(InfrDomains.key(domain) == Enums.InfrDomain.find_key(domain), "JSON key equals the enum name for %s" % InfrDomains.title(domain))
	check(InfrDomains.stop_id_key(rail) == "trackNum" and InfrDomains.stop_id_key(road) == "roadNum", "Stop anchors use the interchange field names")
	check(InfrDomains.default_type(rail) == "NORMAL_GAUGE" and InfrDomains.default_type(road) == "rural_road", "New lines get the default rail gauge and road type")
	check(InfrDomains.singular(road) == "road" and InfrDomains.plural(rail) == "rails" and InfrDomains.title(rail) == "Rail", "Labels read naturally")
	## Node names must match the runtime nodes (RoadWay.get_node_name / RailTrack), which pickers rely on.
	check(InfrDomains.node_name(rail, 7) == "RailTrack_7" and InfrDomains.node_name(road, 12) == "RoadWay_12", "Line node names follow the runtime naming")
	check(InfrDomains.editor_color(rail) != InfrDomains.editor_color(road), "Rails and roads are told apart by colour")
	check(InfrDomains.preview_color(road) != InfrDomains.editor_color(road), "A line being drawn stands out from saved lines")
	check(InfrDomains.line_material(rail) != null and InfrDomains.line_material(road) != null
		and InfrDomains.line_material(rail) != InfrDomains.line_material(road), "Each domain has its own line material")
	var rails := GeneratedRailLines.new()
	var roads := GeneratedRoadWays.new()
	var plain := Node3D.new()
	check(InfrDomains.is_reference_container(rails, rail) and not InfrDomains.is_reference_container(rails, road),
		"Rail reference lines live in GeneratedRailLines only")
	check(InfrDomains.is_reference_container(roads, road) and not InfrDomains.is_reference_container(plain, road),
		"Road reference lines live in GeneratedRoadWays only")
	for node: Node in [rails, roads, plain]:
		node.free()
	return true

func test_cache_lookup() -> bool:
	var world := WorldMapScene.new()
	root.add_child(world)
	check(EditorCache.find(world) == null, "A map without a cache has none to find")
	var cache: Node3D = EditorCache.ensure_container(world, Enums.InfrDomain.ROAD)
	check(cache.name == EditorCache.NODE_NAME and EditorCache.find(world) == cache, "The created cache is found by its name")
	check(EditorCache.ensure_container(world, Enums.InfrDomain.RAIL) == cache, "Both domains share one cache per map")
	check(cache.has_meta("initialized_roads") and cache.has_meta("initialized_rails"), "Cache upgrade keys keep their names per domain")
	world.free()
	return true

func test_owning_map() -> bool:
	var world := WorldMapScene.new()
	var middle := Node3D.new()
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRail(5, "Nested")
	middle.add_child(line)
	world.add_child(middle)
	check(WorldUtils.owning_map(line) == world, "A nested line finds its map scene")
	check(WorldUtils.owning_map(world) == null, "A map scene is not its own owner")
	var loose: EditorInfrLine3D = EditorInfrLine3D.ofRoad(6, "Loose")
	check(WorldUtils.owning_map(loose) == null, "A line outside any map has no owner")
	loose.free()
	world.free()
	return true

func test_line_storage() -> bool:
	var line: EditorInfrLine3D = EditorInfrLine3D.ofRail(8, "Stored")
	var usage: Dictionary = {}
	for property: Dictionary in line.get_property_list():
		usage[property.name] = property.usage
	## Derived values stay visible but are never written into map scenes.
	for name: String in ["color", "abs_aabb"]:
		check(usage.has(name) and usage[name] & PROPERTY_USAGE_EDITOR and not usage[name] & PROPERTY_USAGE_STORAGE,
			"%s is shown in the inspector but not saved" % name)
	check(usage.has("material") and not usage["material"] & PROPERTY_USAGE_STORAGE, "The line material is not saved")
	## The authored data still is.
	for name: String in ["num", "infr_name", "infr_domain", "curve"]:
		check(usage.has(name) and usage[name] & PROPERTY_USAGE_STORAGE, "%s is still saved" % name)
	## A saved and reloaded line comes back without the derived values but with its own material.
	var scene := PackedScene.new()
	check(scene.pack(line) == OK, "The line packs into a scene")
	var state: SceneState = scene.get_state()
	var stored: Array[String] = []
	for index: int in range(state.get_node_property_count(0)):
		stored.append(state.get_node_property_name(0, index))
	check(not stored.has("color") and not stored.has("abs_aabb") and not stored.has("material"), "A saved line holds no derived values")
	line.free()
	return true
