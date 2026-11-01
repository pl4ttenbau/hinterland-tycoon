extends Node

var failures: int = 0
var categories: Array[StringName] = []
var failed_loader_completions: int = 0
var completion_count: int = 0
var session_ready_count: int = 0
var completion_had_all_types: bool = false
var residence_loader_completions: int = 0

func _ready() -> void:
	self._run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		self.failures += 1
		push_error(message)

func _on_catalog_loaded(category: StringName) -> void:
	self.categories.append(category)
	self.check(GameTypes.is_initializing, "Category events occur during initialization")
	self.check(GameTypes.ensure_initialized() == ERR_BUSY, "Reentrant initialization cannot start a second load")

func _on_initialized() -> void:
	self.completion_count += 1
	self.completion_had_all_types = GameTypes.is_initialized and not GameTypes.is_initializing \
		and not GameTypes.resource_types.is_empty() and not GameTypes.infr_types.is_empty() \
		and not GameTypes.industry_types.is_empty() and not GameTypes.res_bld_type_store.get_all().is_empty() \
		and not GameTypes.vehicle_types_dict.is_empty()

func _on_session_ready() -> void:
	self.session_ready_count += 1
	self.check(self.completion_had_all_types and Managers.are_world_services_initialized(), "Session readiness follows catalog and services completion")

func _run() -> void:
	self.check(self.test_catalog_lifecycle(), "Catalog lifecycle test finished")
	self.check(self.test_invalid_catalogs(), "Invalid catalog test finished")
	self.check(self.test_road_catalogs(), "Road catalog test finished")
	self.check(self.test_residence_catalogs(), "Residence catalog test finished")
	self.check(self.test_map_locations(), "Map location test finished")
	print("Type catalog tests: %d failures" % self.failures)
	get_tree().quit(1 if self.failures > 0 else 0)

func test_catalog_lifecycle() -> bool:
	self.check(not GameTypes.is_initialized, "Catalog initialization is explicit")
	var unused_loader := GoodsTypesLoader.new()
	self.check(GameTypes.resource_types.is_empty(), "Constructing a loader does not load definitions")
	unused_loader = null
	SignalBus.type_catalog_loaded.connect(self._on_catalog_loaded)
	SignalBus.all_types_initialized.connect(self._on_initialized)
	var first_session := GameSession.new()
	first_session.add_child(load("res://scenes/subscenes/world_services.tscn").instantiate())
	first_session.scene_root_ready.connect(self._on_session_ready)
	self.add_child(first_session)
	self.check(self.completion_had_all_types, "Completion includes vehicles and every other catalog")
	self.check(self.categories == [&"goods", &"infrastructure", &"industries", &"residences", &"rail_vehicles", &"road_vehicles"], "All categories load in dependency order")
	self.check(self.session_ready_count == 1, "First session starts after loading")
	var source_catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(RailVehicleTypesLoader.CATALOG_PATH))
	var road_catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(RoadVehicleTypesLoader.CATALOG_PATH))
	self.check(source_catalog.size() == 17 and GameTypes.vehicle_types.size() == source_catalog.size() + road_catalog.size(), "Rail and road catalogs load together")
	for index: int in range(source_catalog.size()):
		var vehicle: VehicleTypeData = GameTypes.vehicle_types[index]
		self.check(vehicle is RailVehicleTypeData, "Rail catalog creates rail definitions")
		self.check(vehicle.mass_tonnes == source_catalog[index].get("mass_tonnes") and vehicle.motor_power_kw == source_catalog[index].get("motor_power_kw"), "Catalog mass and power values are preserved")
		self.check(vehicle.usable_infr.domain == Enums.InfrDomain.RAIL, "Rail loader supplies the runtime domain")
	self.check(GameTypes.get_veh_type("loco_faur").max_speed_kmh == 45, "Current FAUR speed survives migration")
	self.check(is_equal_approx(GameTypes.get_veh_type("loco_faur").length_metres, 9.5), "Vehicle length survives migration")
	self.check(GameTypes.get_veh_type("wismar_railbus").capacity.amount == 65, "Current railbus capacity survives migration")
	self.check(GameTypes.get_veh_type("mpsb_open_wagon").capacity.goods_cat == BaseGoodsType.ResourceCategory.AGGREGATE, "Capacity category survives migration")
	var first_vehicle: VehicleTypeData = GameTypes.vehicle_types[0]
	self.check(GameTypes.get_veh_type(first_vehicle.key) == first_vehicle, "Vehicle array and lookup share definitions")
	self.check(GameTypes.get_res_bld_type("wooden_shack") != null, "Residential lookup works")
	self.check(GameTypes.res_bld_type_store.get_all().size() == 35, "All migrated residence types load")
	self.check(GameTypes.get_res_bld_type("ru_stalinka_1").pops == [55, 18], "Residence population values survive migration")
	self.check(GameTypes.get_res_bld_type("village_house_3").pops == [4, 1], "Residence population division keeps its original rounding")
	self.check(GameTypes.get_res_bld_type("city_manor").block_auto_placement, "Manual-only residence flag survives migration")
	var first_residence: ResBldType = GameTypes.get_res_bld_type("wooden_shack")
	self.check(GameTypes.get_rnd_placable_res_bld() != null, "Random residential lookup works")
	first_session.free()
	var later_session := GameSession.new()
	later_session.add_child(load("res://scenes/subscenes/world_services.tscn").instantiate())
	later_session.scene_root_ready.connect(self._on_session_ready)
	self.add_child(later_session)
	self.check(GameTypes.ensure_initialized() == OK, "Repeated initialization succeeds")
	self.check(self.completion_count == 1 and self.categories.size() == 6, "Scene changes do not reload or repeat completion events")
	self.check(self.session_ready_count == 2, "Late session starts using persistent readiness")
	self.check(GameTypes.get_veh_type(first_vehicle.key) == first_vehicle, "Scene changes preserve definition identity")
	self.check(GameTypes.get_res_bld_type(first_residence.key) == first_residence, "Scene changes preserve residence definition identity")
	later_session.free()
	return true

func _on_failed_loader_finished() -> void:
	self.failed_loader_completions += 1

func test_invalid_catalogs() -> bool:
	var path: String = "/tmp/hinterland-rail-catalog-%d.json" % OS.get_process_id()
	var raw_catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(RailVehicleTypesLoader.CATALOG_PATH))
	var wrong_domain: Dictionary = raw_catalog[0].duplicate(true)
	wrong_domain["usable_infr"]["domain"] = "ROAD"
	var wrong_speed: Dictionary = raw_catalog[0].duplicate(true)
	wrong_speed["max_speed_kmh"] = "fast"
	var populated: Dictionary = raw_catalog[0].duplicate(true)
	populated["mass_tonnes"] = null
	populated["motor_power_kw"] = null
	var unknown: RailVehicleTypeData = VehicleMapper.rail_type_dict_to_class(populated)
	self.check(unknown != null and unknown.mass_tonnes == null and unknown.motor_power_kw == null, "Unknown mass and power remain null")
	populated["mass_tonnes"] = 32
	populated["motor_power_kw"] = 331.5
	var mapped: RailVehicleTypeData = VehicleMapper.rail_type_dict_to_class(populated)
	self.check(mapped != null and mapped.mass_tonnes == 32.0 and mapped.motor_power_kw == 331.5, "Mass and power load when supplied")
	self.check(not populated["usable_infr"].has("domain"), "Mapping does not mutate the source definition")
	var invalid_mass: Dictionary = populated.duplicate(true)
	invalid_mass["mass_tonnes"] = "unknown"
	var invalid_power: Dictionary = populated.duplicate(true)
	invalid_power["motor_power_kw"] = -1
	var existing_count: int = GameTypes.vehicle_types.size()
	var fixture_contents: Array[String] = [
		"{broken json", "{}", JSON.stringify([raw_catalog[0], raw_catalog[0]]),
		JSON.stringify([wrong_domain]), JSON.stringify([wrong_speed]),
		JSON.stringify([invalid_mass]), JSON.stringify([invalid_power])
	]
	print("Checking invalid catalogs; the following validation errors are expected.")
	for contents: String in fixture_contents:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(contents)
		file.close()
		var loader := RailVehicleTypesLoader.new()
		loader.catalog_path = path
		loader.loading_finished.connect(self._on_failed_loader_finished)
		self.check(loader.load_types() != OK, "Invalid catalogs are rejected")
		self.check(GameTypes.vehicle_types.size() == existing_count, "Rejected catalogs do not partially register definitions")
	self.check(self.failed_loader_completions == 0, "Failed loaders never announce completion")
	DirAccess.remove_absolute(path)
	return true

func test_road_catalogs() -> bool:
	var source: Array = JSON.parse_string(FileAccess.get_file_as_string(RoadVehicleTypesLoader.CATALOG_PATH))
	self.check(source.size() == 3 and GameTypes.get_veh_type("trabant_601_green") is RoadVehicleTypeData, "Road catalog includes the oldtimer, GAZ truck and green Trabant")
	for entry: Dictionary in source:
		var definition: VehicleTypeData = GameTypes.get_veh_type(entry["key"])
		self.check(definition is RoadVehicleTypeData, "Road catalog creates road definitions")
		if not definition is RoadVehicleTypeData:
			continue
		self.check(definition.usable_infr.domain == Enums.InfrDomain.ROAD, "Road domain is supplied by its catalog")
		self.check(definition.max_speed_kmh == entry.get("max_speed_kmh") \
			and definition.mass_tonnes == entry.get("mass_tonnes") \
			and definition.motor_power_kw == entry.get("motor_power_kw"), "Known specifications load and unknown specifications remain null")
		if entry.get("capacity") == null:
			self.check(definition.capacity == null, "Unknown road capacity remains null")
		else:
			self.check(definition.capacity != null and definition.capacity.amount == int(entry["capacity"]["amount"]) \
				and definition.capacity.goods_cat == BaseGoodsType.ResourceCategory[entry["capacity"]["cat"]], "Road capacity loads its amount and shared goods category")
		self.check(definition.payload_tonnes == entry.get("payload_tonnes"), "Physical payload loads independently of game cargo counts")
		self.check(definition.get_mesh_path() == entry["model_scene_path"] \
			and FileAccess.file_exists(definition.get_mesh_path()), "Road model path is explicit and exists")
		self.check(definition.width_metres == entry["width_metres"] \
			and definition.height_metres == entry["height_metres"], "Model dimensions load from JSON")
	# Complete specifications can be authored later without changing the mapper.
	var populated: Dictionary = source[0].duplicate(true)
	populated["max_speed_kmh"] = 40
	populated["capacity"] = {"cat": "PASSENGER", "amount": 4}
	populated["payload_tonnes"] = 0
	var mapped: RoadVehicleTypeData = VehicleMapper.road_type_dict_to_class(populated)
	self.check(mapped != null and mapped.max_speed_kmh == 40 and mapped.capacity.amount == 4, "Road specifications load when supplied")
	self.check(mapped != null and mapped.payload_tonnes == 0, "Explicit zero payload is distinct from unknown payload")
	self.check(not populated["usable_infr"].has("domain"), "Road mapping leaves source data unchanged")
	var existing_count: int = GameTypes.vehicle_types.size()
	var path: String = "/tmp/hinterland-road-catalog-%d.json" % OS.get_process_id()
	var invalid_fields: Array[Dictionary] = [
		{"usable_infr": {"domain": "RAIL"}}, {"max_speed_kmh": "fast"},
		{"max_speed_kmh": 0}, {"max_speed_kmh": 1.5}, {"length_metres": -1},
		{"width_metres": 0}, {"height_metres": -1},
		{"payload_tonnes": -1}, {"payload_tonnes": "1.5"}, {"payload_tonnes": true},
		{"capacity": {"cat": "PASSENGER", "amount": -1}}
	]
	var contents: Array[String] = ["{broken", "{}", "[]", "[null]", JSON.stringify(source)]
	for fields: Dictionary in invalid_fields:
		var invalid: Dictionary = populated.duplicate(true)
		invalid.merge(fields, true)
		invalid["key"] = "invalid_road_fixture"
		var valid: Dictionary = populated.duplicate(true)
		valid["key"] = "valid_road_fixture"
		contents.append(JSON.stringify([valid, invalid]))
	var duplicate: Dictionary = populated.duplicate(true)
	duplicate["key"] = "duplicate_road_fixture"
	contents.append(JSON.stringify([duplicate, duplicate]))
	duplicate["key"] = "loco_faur"
	contents.append(JSON.stringify([duplicate]))
	print("Checking invalid road catalogs; the following validation errors are expected.")
	for fixture: String in contents:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(fixture)
		file.close()
		var loader := RoadVehicleTypesLoader.new()
		loader.catalog_path = path
		loader.loading_finished.connect(self._on_failed_loader_finished)
		self.check(loader.load_types() != OK, "Invalid road catalogs are rejected")
		self.check(GameTypes.vehicle_types.size() == existing_count \
			and not GameTypes.vehicle_types_dict.has("valid_road_fixture"), "Rejected road catalogs register no partial batch")
	self.check(self.failed_loader_completions == 0, "Failed road loaders never announce completion")
	DirAccess.remove_absolute(path)
	return true

func _on_residence_loader_finished() -> void:
	self.residence_loader_completions += 1

func test_residence_catalogs() -> bool:
	var path: String = "/tmp/hinterland-residence-catalog-%d.json" % OS.get_process_id()
	var original_store: ResBldTypeStore = GameTypes.res_bld_type_store
	var source: Array = JSON.parse_string(FileAccess.get_file_as_string(ResidentialBldTypeLoader.CATALOG_PATH))
	for entry: Dictionary in source:
		var definition: ResBldType = original_store.get_by_key(entry["key"])
		self.check(definition != null, "Every residence catalog key is registered")
		if definition == null:
			continue
		self.check(definition.name == entry["name"] and definition.pops[0] == int(entry["pops"][0]) \
			and definition.pops[1] == int(entry["pops"][1]), "Residence name and both population counts load from JSON")
		self.check(definition.get_scene_path() == entry["scene_path"] and definition.block_auto_placement == entry["block_auto_placement"], "Residence scene and placement flag load from JSON")
		self.check(definition.themes.size() == entry["themes"].size(), "All residence themes are loaded")
		for theme_name: String in entry["themes"]:
			self.check(definition.themes.has(Enums.Location[theme_name]), "Residence theme names map to shared location enum values")
	var loader := ResidentialBldTypeLoader.new()
	loader.catalog_path = path + ".missing"
	loader.loading_finished.connect(self._on_residence_loader_finished)
	self.check(loader.load_types() != OK, "Missing residence catalog is rejected")
	self.check(GameTypes.res_bld_type_store == original_store, "Missing residence catalog preserves the existing store")
	loader.catalog_path = path
	var fixture_contents: Array[String] = [
		"{broken json", "{}", "[]", "[null]", "[42]", "[{}]",
		JSON.stringify([source[0], source[0]])
	]
	var invalid_fields: Array[Dictionary] = [
		{"key": ""}, {"name": " "}, {"scene_path": "house.tscn"},
		{"scene_path": 123}, {"scene_path": "res://house.obj"},
		{"pops": null}, {"pops": [3]}, {"pops": [3, 1, 0]},
		{"pops": [-1, 0]}, {"pops": [3, 1.5]}, {"pops": [true, 1]},
		{"pops": ["3", 1]}, {"block_auto_placement": "false"},
		{"themes": null}, {"themes": "POLAND"}, {"themes": [2]},
		{"themes": ["poland"]}, {"themes": ["UNKNOWN"]},
		{"themes": ["POLAND", "POLAND"]}
	]
	for fields: Dictionary in invalid_fields:
		var invalid: Dictionary = source[0].duplicate(true)
		invalid.merge(fields, true)
		# A valid first entry must not be registered before a later invalid one.
		fixture_contents.append(JSON.stringify([source[1], invalid]))
	print("Checking invalid residence catalogs; the following validation errors are expected.")
	for contents: String in fixture_contents:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(contents)
		file.close()
		self.check(loader.load_types() != OK, "Invalid residence catalog is rejected")
		self.check(GameTypes.res_bld_type_store == original_store, "Rejected residence catalog does not replace or partially modify the store")
		self.check(original_store.get_all().size() == source.size(), "Rejected residence catalog preserves all definitions")
	self.check(self.residence_loader_completions == 0, "Failed residence loads never announce completion")
	# An explicit scene may differ from the key, and both counts are authored data.
	var custom: Dictionary = source[0].duplicate(true)
	custom["key"] = "custom_residence"
	custom["pops"] = [7, 5]
	custom["themes"] = ["NORTHERN_GERMANY", "POLAND"]
	custom.erase("block_auto_placement")
	var unclassified: Dictionary = custom.duplicate(true)
	unclassified["key"] = "unclassified_residence"
	unclassified.erase("themes")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify([custom, unclassified]))
	file.close()
	self.check(loader.load_types() == OK, "Valid alternate residence catalog loads")
	var mapped: ResBldType = GameTypes.get_res_bld_type("custom_residence")
	self.check(mapped != null and mapped.pops == [7, 5], "Both residence population counts are preserved without recalculation")
	self.check(mapped != null and mapped.get_scene_path() == source[0]["scene_path"], "Scene lookup honors the catalog path independently of the key")
	self.check(mapped != null and not mapped.block_auto_placement, "Residence auto placement defaults to enabled")
	self.check(mapped != null and mapped.themes == [Enums.Location.NORTHERN_GERMANY, Enums.Location.POLAND], "A residence can belong to multiple enum themes")
	self.check(GameTypes.get_res_bld_type("unclassified_residence").themes.is_empty(), "Missing themes leave a residence unclassified")
	self.check(self.residence_loader_completions == 1, "Successful residence loading announces completion once")
	GameTypes.res_bld_type_store = original_store
	DirAccess.remove_absolute(path)
	return true

func test_map_locations() -> bool:
	var expected: Dictionary = {
		"franzburger": Enums.Location.NORTHERN_GERMANY,
		"mpsb": Enums.Location.NORTHERN_GERMANY,
		"harzmountains": Enums.Location.SOUTHERN_GERMANY,
		"sachalin": Enums.Location.SOVIET_UNION
	}
	for map_key: String in expected:
		var map: MapData = MapData.parse(map_key)
		self.check(map != null and map.loc == expected[map_key], "Map location uses the shared enum: %s" % map_key)
	print("Checking invalid map locations; the following validation errors are expected.")
	for invalid: Variant in ["poland", "UNKNOWN", 2, null]:
		self.check(MapData.of_dict({"key": "invalid", "loc": invalid}) == null, "Map rejects unknown or non-string locations")
	return true
