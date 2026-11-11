extends RefCounted

const Result = IndustryProduction.BatchResult

var failures: int = 0
var checks: int = 0

func run() -> int:
	check(GameTypes.ensure_initialized() == OK, "The goods and recipe catalogs load")
	var cases: Array[Callable] = [
		test_missing_inputs,
		test_output_capacity,
		test_producer_and_consumer,
		test_invalid_output,
		test_tagged_passengers,
		test_milk,
	]
	for test: Callable in cases:
		check(test.call() == true, "%s completed" % test.get_method())
	print("Industry production tests: %d checks, %d failures" % [checks, failures])
	return 0 if failures == 0 else 1

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func make_inventory(capacity: float) -> GoodsInventory:
	var inventory := GoodsInventory.new()
	inventory.amount_max = capacity
	return inventory

func test_missing_inputs() -> bool:
	var inventory: GoodsInventory = make_inventory(20)
	inventory.add_goods_amount(GoodsAmount.new("lumber", 5))
	var recipe := IndustryType.new("TEST", "Test sawmill", "", 0, ["3xlumber", "3xlumber"], ["2xboards"])

	# Each input line fits alone. The whole batch needs six lumber.
	check(IndustryProduction.run_batch(recipe, inventory) == Result.MISSING_INPUTS, "Repeated inputs count toward one requirement")
	check(inventory.get_amount("lumber") == 5 and inventory.get_amount("boards") == 0, "Missing input leaves all stock untouched")
	return true

func test_output_capacity() -> bool:
	var inventory: GoodsInventory = make_inventory(5)
	inventory.add_goods_amount(GoodsAmount.new("coal", 5))
	var recipe := IndustryType.new("TEST", "Test converter", "", 0, ["1xcoal"], ["2xboards"])
	var observed_stock: Array[Vector2] = []
	var observe_stock: Callable = func() -> void:
		observed_stock.append(Vector2(inventory.get_amount("coal"), inventory.get_amount("boards")))
	inventory.goods_change.connect(observe_stock)

	check(IndustryProduction.run_batch(recipe, inventory) == Result.STORAGE_FULL, "The full output batch must fit")
	check(inventory.get_amount("coal") == 5 and observed_stock.is_empty(), "A full store keeps the inputs and emits no change")

	# With four coal in stock, the output fits only after consuming the input.
	inventory.remove_goods_amount(GoodsAmount.new("coal", 1))
	observed_stock.clear()
	check(IndustryProduction.run_batch(recipe, inventory) == Result.COMPLETED, "Inputs free space for the same batch")
	check(observed_stock == [Vector2(3, 2)] and inventory.amount_used == 5, "Observers receive one complete inventory update")
	inventory.goods_change.disconnect(observe_stock)
	return true

func test_producer_and_consumer() -> bool:
	var inventory: GoodsInventory = make_inventory(4)
	var mine: IndustryType = GameTypes.get_ind_type("COAL_MINE")
	var plant: IndustryType = GameTypes.get_ind_type("COAL_PLANT")

	check(IndustryProduction.run_batch(mine, inventory) == Result.COMPLETED, "A mine can produce without inputs")
	check(IndustryProduction.run_batch(mine, inventory) == Result.STORAGE_FULL, "A full mine stops producing")
	check(IndustryProduction.run_batch(plant, inventory) == Result.COMPLETED, "A coal plant can consume without outputs")
	check(inventory.get_amount("coal") == 0, "The plant removes its coal requirement")
	check(IndustryProduction.run_batch(plant, inventory) == Result.MISSING_INPUTS, "The plant needs another delivery")
	return true

func test_invalid_output() -> bool:
	var inventory: GoodsInventory = make_inventory(10)
	inventory.add_goods_amount(GoodsAmount.new("lumber", 2))
	var invalid := IndustryType.new("TEST", "Invalid converter", "", 0, ["2xlumber"], ["1xboards", "1xunknown"])
	check(IndustryProduction.run_batch(invalid, inventory) == Result.INVALID_RECIPE, "Unknown output rejects the whole recipe")
	check(inventory.get_amount("lumber") == 2 and inventory.get_amount("boards") == 0, "Invalid output leaves inputs and other outputs untouched")
	return true

func test_tagged_passengers() -> bool:
	var inventory: GoodsInventory = make_inventory(10)
	inventory.change_stack(&"soldier", 17, 2)
	var passenger_consumer := IndustryType.new("TEST", "Passenger consumer", "", 0, ["1xsoldier"], [])
	check(IndustryProduction.run_batch(passenger_consumer, inventory) == Result.MISSING_INPUTS, "Destination-tagged passengers cannot satisfy recipes")
	check(inventory.stack_amount(&"soldier", 17) == 2, "The tagged batch remains available for its trip")
	return true

func test_milk() -> bool:
	var inventory: GoodsInventory = make_inventory(2)
	var milk: BaseGoodsType = GameTypes.resource_types.get(&"milk")
	check(milk != null and milk.res_cat == BaseGoodsType.ResourceCategory.LIQUID, "Milk is registered as liquid cargo")

	var recipe := IndustryType.new("TEST", "Test dairy", "", 0, [], ["1.5xmilk"])
	check(IndustryProduction.run_batch(recipe, inventory) == Result.COMPLETED, "Liquid recipes support fractional quantities")
	check(inventory.get_amount("milk") == 1.5, "The batch preserves the fractional output")
	return true
