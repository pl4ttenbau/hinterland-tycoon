extends RefCounted

var failures: int = 0
var tree: SceneTree

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	for test: Callable in [test_incentives, test_unknown_specs, test_stored_prices, test_catalog_and_dialog]:
		check(await test.call() == true, "%s completed without runtime errors" % test.get_method())
	print("Road vehicle pricing tests: %d failures" % failures)
	return 1 if failures > 0 else 0

func vehicle() -> RoadVehicleTypeData:
	var definition := RoadVehicleTypeData.new()
	definition.has_motor = true
	definition.max_speed_kmh = 80
	definition.motor_power_kw = 40.0
	definition.capacity = GoodsCapacity.of(4, BaseGoodsType.ResourceCategory.PASSENGER)
	return definition

func test_incentives() -> bool:
	var definition: RoadVehicleTypeData = vehicle()
	var base: int = definition.get_purchase_price()
	check(base == 11300, "Reference price rounds up to 100 DM")
	definition.max_speed_kmh = 100
	check(definition.get_purchase_price() > base, "Higher speed costs more")
	definition.max_speed_kmh = 80
	definition.motor_power_kw = 60.0
	check(definition.get_purchase_price() > base, "More power costs more")
	definition.motor_power_kw = 40.0
	definition.capacity.amount = 10
	check(definition.get_purchase_price() > base, "More capacity costs more")
	definition.capacity.amount = 4
	definition.mass_tonnes = 2.0
	definition.payload_tonnes = 1.5
	check(definition.get_purchase_price() == base, "Physical mass and payload do not double-count game capacity")
	var balance: Resource = RoadVehicleTypeData.PRICING.duplicate()
	balance.price_per_kw *= 2.0
	check(balance.price_for(definition) > base, "Balance coefficients are tunable independently of the catalog")
	definition.capacity.amount = 0
	check(definition.get_purchase_price() > 0, "Known zero capacity still pays for chassis and motor")
	return true

func test_unknown_specs() -> bool:
	var definition: RoadVehicleTypeData = vehicle()
	definition.max_speed_kmh = null
	check(definition.get_purchase_price() == null, "Unknown speed is unpriced")
	definition.max_speed_kmh = 80
	definition.motor_power_kw = null
	check(definition.get_purchase_price() == null, "Unknown power is unpriced")
	definition.motor_power_kw = 40.0
	definition.capacity = null
	check(definition.get_purchase_price() == null, "Unknown capacity is unpriced")
	definition.capacity = GoodsCapacity.of(4, BaseGoodsType.ResourceCategory.PASSENGER)
	definition.has_motor = false
	check(definition.get_purchase_price() == null, "Trailer pricing is not silently inferred")
	return true

func test_catalog_and_dialog() -> bool:
	check(GameTypes.ensure_initialized() == OK, "Catalog initializes with road prices")
	var expected: Dictionary = {
		"oldtimer_car": 12300, "gaz_aa_truck": 9700, "trabant_601_green": 9600,
		"daimler_1911_bus": 12000, "ifa_w50_covered": 23900,
	}
	for key: String in expected:
		check(GameTypes.get_veh_type(key).get_purchase_price() == expected[key], "%s gets its catalog price" % key)
		var definition: RoadVehicleTypeData = GameTypes.get_veh_type(key)
		# The Daimler has a hand-set price. Other catalog prices follow the generator.
		if key != "daimler_1911_bus":
			check(definition.purchase_price == RoadVehicleTypeData.PRICING.price_for(definition), "Stored road price matches the generator")
	var depot := RoadDepotData.new()
	depot.depot_name = "Pricing test depot"
	var dialog: RoadVehicleSpawnDialog = RoadVehicleSpawnDialog.create(depot)
	tree.root.add_child(dialog)
	await tree.process_frame
	var types: Array = dialog.get("_types")
	var details: Label = dialog.get("_details")
	check(types.size() == expected.size(), "Dialog includes all road types")
	for index: int in range(types.size()):
		dialog._on_vehicle_selected(index)
		check(details.text.contains("Purchase price: DM %d" % expected[types[index].key]), "Selection updates the purchase price")
	var first: RoadVehicleTypeData = types[0]
	var original_speed: Variant = first.max_speed_kmh
	var original_price: Variant = first.purchase_price
	first.max_speed_kmh = null
	first.purchase_price = null
	dialog._on_vehicle_selected(0)
	check(details.text.contains("Price unknown"), "Missing specs clear the previous selection's price")
	first.max_speed_kmh = original_speed
	first.purchase_price = original_price
	dialog.free()
	return true

func test_stored_prices() -> bool:
	var road_source: Array = JSON.parse_string(FileAccess.get_file_as_string(RoadVehicleTypesLoader.CATALOG_PATH))
	var rail_source: Array = JSON.parse_string(FileAccess.get_file_as_string(RailVehicleTypesLoader.CATALOG_PATH))
	for domain: String in ["road", "rail"]:
		var entry: Dictionary = (road_source[0] if domain == "road" else rail_source[0]).duplicate(true)
		entry["purchase_price"] = 12345
		entry["motor_power_kw"] = null
		var mapper: Callable = VehicleMapper.road_type_dict_to_class if domain == "road" else VehicleMapper.rail_type_dict_to_class
		var definition: VehicleTypeData = mapper.call(entry)
		check(definition.purchase_price == 12345 and definition.get_purchase_price() == 12345, "Stored %s price wins even without formula inputs" % domain)
		for value: Variant in [null, "omitted"]:
			entry["purchase_price"] = value
			if value is String:
				entry.erase("purchase_price")
			definition = mapper.call(entry)
			check(definition != null and definition.purchase_price == null, "Unknown or omitted prices remain null")
		print("The following invalid-price validation errors are expected:")
		for invalid: Variant in [-1, 0, 12.5, "100", true, INF, NAN]:
			entry["purchase_price"] = invalid
			check(mapper.call(entry) == null, "Invalid %s purchase price is rejected" % domain)
	return true
