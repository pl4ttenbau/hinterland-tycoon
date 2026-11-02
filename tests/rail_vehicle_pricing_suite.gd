extends RefCounted

var failures: int = 0
var tree: SceneTree

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	for test: Callable in [test_locomotives, test_wagons, test_unknown_specs, test_catalog_and_ui]:
		check(await test.call() == true, "%s completed without runtime errors" % test.get_method())
	print("Rail vehicle pricing tests: %d failures" % failures)
	return 1 if failures > 0 else 0

func locomotive() -> RailVehicleTypeData:
	var vehicle := RailVehicleTypeData.new()
	vehicle.has_motor = true
	vehicle.max_speed_kmh = 50
	vehicle.motor_power_kw = 400.0
	vehicle.tractive_effort_kn = 100.0
	return vehicle

func test_locomotives() -> bool:
	var vehicle: RailVehicleTypeData = locomotive()
	var base: int = vehicle.get_purchase_price()
	check(base == 233800, "Reference locomotive price rounds up to 100 DM")
	vehicle.motor_power_kw = 800.0
	check(vehicle.get_purchase_price() > base, "More power costs more")
	vehicle.motor_power_kw = 400.0
	vehicle.max_speed_kmh = 100
	check(vehicle.get_purchase_price() > base, "Higher locomotive speed costs more")
	vehicle.max_speed_kmh = 50
	vehicle.tractive_effort_kn = 200.0
	check(vehicle.get_purchase_price() > base, "More pulling strength costs more")
	vehicle.tractive_effort_kn = 100.0
	vehicle.capacity = GoodsCapacity.of(50, BaseGoodsType.ResourceCategory.PASSENGER)
	check(vehicle.get_purchase_price() > base, "Railcar capacity is charged in addition to its motor")
	vehicle.tractive_effort_kn = null
	vehicle.mass_tonnes = 40.0
	check(RailVehicleTypeData.PRICING.uses_estimated_strength(vehicle), "Mass fallback is marked as estimated")
	check(is_equal_approx(RailVehicleTypeData.PRICING.tractive_effort_for(vehicle), 98.1), "Mass estimate uses tonnes, gravity and adhesion")
	vehicle.tractive_effort_kn = 120.0
	check(not RailVehicleTypeData.PRICING.uses_estimated_strength(vehicle), "Authored strength replaces the estimate")
	check(RailVehicleTypeData.PRICING.tractive_effort_for(vehicle) == 120.0, "Authored strength takes priority over mass")
	return true

func test_wagons() -> bool:
	var vehicle := RailVehicleTypeData.new()
	vehicle.max_speed_kmh = 60
	vehicle.capacity = GoodsCapacity.of(50, BaseGoodsType.ResourceCategory.FREIGHT)
	var base: int = vehicle.get_purchase_price()
	check(base == 19200, "Reference wagon price rounds up to 100 DM")
	vehicle.capacity.amount = 100
	check(vehicle.get_purchase_price() > base, "More wagon capacity costs more")
	vehicle.capacity.amount = 50
	vehicle.max_speed_kmh = 100
	check(vehicle.get_purchase_price() > base, "Higher wagon speed costs more")
	vehicle.max_speed_kmh = 60
	vehicle.motor_power_kw = 9999.0
	vehicle.mass_tonnes = 9999.0
	check(vehicle.get_purchase_price() == base, "Wagon price is independent of motor and empty mass")
	vehicle.capacity.amount = 0
	check(vehicle.get_purchase_price() > 0, "Explicit zero capacity still has a base price")
	return true

func test_unknown_specs() -> bool:
	var vehicle: RailVehicleTypeData = locomotive()
	vehicle.max_speed_kmh = null
	check(vehicle.get_purchase_price() == null, "Unknown speed is unpriced")
	vehicle.max_speed_kmh = 50
	vehicle.motor_power_kw = null
	check(vehicle.get_purchase_price() == null, "Unknown motor power is unpriced")
	vehicle.motor_power_kw = 400.0
	vehicle.tractive_effort_kn = null
	check(vehicle.get_purchase_price() == null, "Missing strength and mass cannot produce a price")
	vehicle.mass_tonnes = 20.0
	check(vehicle.get_purchase_price() is int, "Known mass enables an estimated price")
	vehicle.has_motor = false
	check(vehicle.get_purchase_price() == null, "Missing wagon capacity is unpriced")
	check(RoadVehicleTypeData.new().get_purchase_price() == null, "Road vehicles with unknown specs remain unpriced")
	return true

func test_catalog_and_ui() -> bool:
	check(GameTypes.ensure_initialized() == OK, "Catalog initializes with pricing support")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string(RailVehicleTypesLoader.CATALOG_PATH))
	var authored: Dictionary = catalog[0].duplicate(true)
	authored["tractive_effort_kn"] = 123.5
	var mapped: RailVehicleTypeData = VehicleMapper.rail_type_dict_to_class(authored)
	check(mapped != null and mapped.tractive_effort_kn == 123.5, "Mapper preserves authored kN")
	check(not catalog[0].has("tractive_effort_kn"), "Existing catalogs need no invented strength values")
	print("The next validation error is expected:")
	authored["tractive_effort_kn"] = -1
	check(VehicleMapper.rail_type_dict_to_class(authored) == null, "Negative strength is rejected")
	var item_scene: PackedScene = load("res://scenes/ui/list/vehicle_list/vehicle_list_item.tscn")
	for definition: VehicleTypeData in GameTypes.vehicle_types:
		if not definition is RailVehicleTypeData:
			continue
		var price: Variant = definition.get_purchase_price()
		check(price is int and price > 0 and price % 100 == 0, "%s has a positive rounded price" % definition.key)
		var item: VehicleListItemUi = item_scene.instantiate()
		item.veh_type_key = definition.key
		item.headline_text = definition.display_name
		item.set_anchors_preset(Control.PRESET_TOP_LEFT)
		item.size = Vector2(350, 99)
		tree.root.add_child(item)
		await tree.process_frame
		await tree.process_frame
		var label: Label = item.get_node("%PurchasePriceLabel")
		var expected: String = "%sDM %d" % ["~" if definition.has_motor else "", price]
		check(label.text == expected, "%s displays its computed price and estimate marker" % definition.key)
		var country: Label = item.get_node("HMargin/VehicleListHLayout/VBoxContainer/Control/VehicleTypeCountryLabel")
		check(country.get_global_rect().end.x <= label.get_global_rect().position.x, "Price does not overlap the country label")
		check(label.get_global_rect().end.x <= item.get_global_rect().end.x - 12.0, "Price fits inside the vehicle row")
		item.free()
	return true
