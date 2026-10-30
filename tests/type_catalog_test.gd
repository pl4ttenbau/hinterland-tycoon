extends Node

var failures: int = 0
var categories: Array[StringName] = []
var failed_loader_completions: int = 0
var completion_count: int = 0
var session_ready_count: int = 0
var completion_had_all_types: bool = false

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
	self.check(self.categories == [&"goods", &"infrastructure", &"industries", &"residences", &"rail_vehicles"], "All categories load in dependency order")
	self.check(self.session_ready_count == 1, "First session starts after loading")
	self.check(GameTypes.vehicle_types.size() == 17, "All migrated rail types load")
	var source_catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(RailVehicleTypesLoader.CATALOG_PATH))
	for index: int in range(GameTypes.vehicle_types.size()):
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
	self.check(GameTypes.get_rnd_placable_res_bld() != null, "Random residential lookup works")
	first_session.free()
	var later_session := GameSession.new()
	later_session.add_child(load("res://scenes/subscenes/world_services.tscn").instantiate())
	later_session.scene_root_ready.connect(self._on_session_ready)
	self.add_child(later_session)
	self.check(GameTypes.ensure_initialized() == OK, "Repeated initialization succeeds")
	self.check(self.completion_count == 1 and self.categories.size() == 5, "Scene changes do not reload or repeat completion events")
	self.check(self.session_ready_count == 2, "Late session starts using persistent readiness")
	self.check(GameTypes.get_veh_type(first_vehicle.key) == first_vehicle, "Scene changes preserve definition identity")
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
