@tool
extends RefCounted

var checks: int = 0
var failures: int = 0

func run(tree: SceneTree) -> int:
	check(test_supply_changes(), "Supply changes test completes")
	check(test_alternative_producers(), "Alternative producers test completes")
	check(test_invalid_types(), "Invalid types test completes")
	check(test_map_industries(), "Authored maps test completes")
	if Engine.is_editor_hint():
		check(await test_editor_refresh(tree), "Editor refresh test completes")
	print("Industry supply tests: %d checks, %d failures" % [checks, failures])
	return 1 if failures > 0 else 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func add_industry(industries: WorldIndustries, key: String, label: String) -> IndustryPlaceholder:
	var industry := IndustryPlaceholder.new()
	industry.type_key = key
	industry.ind_name = label
	industries.add_child(industry)
	return industry

func test_supply_changes() -> bool:
	var industries := WorldIndustries.new()
	check(industries._get_configuration_warnings().is_empty(), "Empty maps have no supply warnings")
	add_industry(industries, "BAKERY", "Bakery A")
	add_industry(industries, "BAKERY", "Bakery B")
	var warnings: PackedStringArray = industries._get_configuration_warnings()
	check(warnings.size() == 2, "Two bakeries produce one warning per missing good, not per building")
	check(warnings[0].begins_with("Missing producer for grains."), "Warnings are sorted by good key")
	check(warnings[0].contains("Bakery A, Bakery B"), "Warnings identify all affected industries")
	check(warnings[1].contains("Sugar Mill (SUGAR_MILL)"), "Warnings suggest the actual catalog producer")
	var farm: IndustryPlaceholder = add_industry(industries, "FARM", "Farm")
	check(industries._get_configuration_warnings().size() == 1, "Adding a farm supplies grains")
	add_industry(industries, "SUGAR_MILL", "Sugar Mill")
	check(industries._get_configuration_warnings().is_empty(), "Farm and sugar mill supply both bakery inputs")
	industries.remove_child(farm)
	warnings = industries._get_configuration_warnings()
	check(warnings.size() == 2 and warnings[0].contains("beets") and warnings[1].contains("grains"), "Removing the farm exposes both missing inputs")
	farm.free()
	industries.free()
	return true

func test_alternative_producers() -> bool:
	var industries := WorldIndustries.new()
	add_industry(industries, "COAL_PLANT", "Power Plant")
	var warning: String = industries._get_configuration_warnings()[0]
	check(warning.contains("COAL_MINE") and warning.contains("CHARCOAL_BURNER"), "Either catalog producer is suggested for coal")
	var producer: IndustryPlaceholder = add_industry(industries, "CHARCOAL_BURNER", "Charcoal Burner")
	var warnings: PackedStringArray = industries._get_configuration_warnings()
	check(warnings.size() == 1 and warnings[0].begins_with("Missing producer for lumber."), "An existing coal producer counts even when its own input is missing")
	producer.type_key = "COAL_MINE"
	check(industries._get_configuration_warnings().is_empty(), "Changing a producer type recalculates supply")
	industries.free()
	return true

func test_invalid_types() -> bool:
	var industries := WorldIndustries.new()
	var invalid: IndustryPlaceholder = add_industry(industries, "TYPO", "Broken Industry")
	check(industries._get_configuration_warnings()[0].contains('unknown type "TYPO"'), "Unknown industry types are reported")
	invalid.type_key = "FARM"
	check(industries._get_configuration_warnings().is_empty(), "Fixing an unknown type removes its warning")
	# Nested placeholders do not spawn: the runtime loader only uses direct children.
	var unrelated := Node.new()
	industries.add_child(unrelated)
	var nested := IndustryPlaceholder.new()
	nested.type_key = "BAKERY"
	unrelated.add_child(nested)
	check(industries._get_configuration_warnings().is_empty(), "Unrelated and nested nodes do not change runtime supply")
	industries.free()
	return true

func test_map_industries() -> bool:
	# Read the authored placeholder blocks without loading unrelated terrain assets.
	var expected: Dictionary = {
		"franzburger": ["coal", "ore", "chemicals"],
		"harzmountains": ["chemicals", "fish", "sugar"],
		"mpsb": ["chemicals"],
		"sachalin": ["alcohol", "beets", "fish", "grains", "sugar"]
	}
	var nodes := RegEx.new()
	nodes.compile('(?m)^\\[node name="([^"]+)"[^\\n]* parent="Industries"[^\\n]*\\]\\n([^\\[]*)')
	var type_key := RegEx.new()
	type_key.compile('(?m)^type_key = "([^"]+)"$')
	for map_key: String in expected:
		var source: String = FileAccess.get_file_as_string("res://world/%s/mapscenes/world_%s.tscn" % [map_key, map_key])
		var industries := WorldIndustries.new()
		for node: RegExMatch in nodes.search_all(source):
			var key: RegExMatch = type_key.search(node.get_string(2))
			if key != null:
				add_industry(industries, key.get_string(1), node.get_string(1))
		check(industries.get_child_count() > 0, "Authored industry placeholders found: %s" % map_key)
		var warnings: PackedStringArray = industries._get_configuration_warnings()
		check(warnings.size() == expected[map_key].size(), "Expected missing-good count: %s" % map_key)
		for key: String in expected[map_key]:
			var found: bool = false
			for warning: String in warnings:
				found = found or warning.begins_with("Missing producer for %s." % key)
			check(found, "%s reports missing %s producer" % [map_key, key])
		industries.free()
	return true

func test_editor_refresh(tree: SceneTree) -> bool:
	var industries := WorldIndustries.new()
	tree.root.add_child(industries)
	await tree.process_frame
	await tree.process_frame
	var industry: IndustryPlaceholder = add_industry(industries, "BAKERY", "Bakery")
	check(industries._supply_refresh_pending, "Adding an industry schedules editor warnings")
	await tree.process_frame
	await tree.process_frame
	check(not industries._supply_refresh_pending, "Deferred editor warning refresh completes")
	industry.type_key = "FARM"
	check(industries._supply_refresh_pending, "Retyping schedules editor warnings")
	await tree.process_frame
	await tree.process_frame
	check(industries._get_configuration_warnings().is_empty(), "Retyping removes obsolete warnings")
	industry.ind_name = "Renamed Farm"
	check(industries._supply_refresh_pending, "Renaming an industry schedules updated warning labels")
	await tree.process_frame
	await tree.process_frame
	industries.remove_child(industry)
	check(industries._supply_refresh_pending, "Removing an industry schedules editor warnings")
	await tree.process_frame
	await tree.process_frame
	industry.free()
	industries.free()
	return true
