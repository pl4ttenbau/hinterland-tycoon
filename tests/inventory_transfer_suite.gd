extends RefCounted

var tree: SceneTree
var passed: int = 0
var failures: int = 0
var host: Node3D

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures += 1
		push_error(message)

func run(scene_tree: SceneTree) -> int:
	tree = scene_tree
	GameTypes.ensure_initialized()
	host = Node3D.new()
	tree.root.add_child(host)
	for test: StringName in [&"test_components", &"test_transfers", &"test_passengers", &"test_vehicle_dialog"]:
		if await call(test) != true:
			check(false, "%s aborted" % test)
	host.free()
	print("Inventory transfer tests: %d passed, %d failures" % [passed, failures])
	return 0 if failures == 0 else 1

func endpoint(label: String, capacity: float = 10) -> InventoryEndpoint:
	var owner := Node3D.new()
	owner.name = label
	var component := InventoryContainer.new()
	component.capacity_override = capacity
	owner.add_child(component)
	host.add_child(owner)
	return InventoryEndpoint.from_node(owner)

# Components work on ordinary nodes and retain explicitly authored resource capacities.
func test_components() -> bool:
	var source: InventoryEndpoint = endpoint("Crate")
	var target: InventoryEndpoint = endpoint("OtherCrate")
	check(source.available() and source.inventory() != target.inventory(), "Components own independent inventory data")
	check(source.component().accepts(&"coal") and source.component().free_capacity() == 10, "Empty category filter accepts cargo")
	var component := InventoryContainer.new()
	component.inventory = GoodsInventory.new()
	component.inventory.amount_max = 37
	host.add_child(component)
	check(component.get_inventory().amount_max == 37, "Inherited capacity is retained")
	component.capacity_override = 0
	check(component.get_inventory().amount_max == 0 and component.free_capacity() == 0, "Zero override means no capacity")
	check(InventoryContainer.find_on(null) == null, "Missing entity is safely rejected")
	return true

# Reject every invalid transaction before mutating either endpoint or emitting signals.
func test_transfers() -> bool:
	var source: InventoryEndpoint = endpoint("Source")
	var target: InventoryEndpoint = endpoint("Target", 2)
	source.inventory().add_goods_amount(GoodsAmount.new("coal", 5))
	var stack := InventoryStack.new(&"coal", 5)
	var notifications: Array[int] = [0]
	source.inventory().goods_change.connect(func():
		notifications[0] += 1
		check(target.inventory().get_amount("coal") == 2, "Observers see both inventories after mutation"))

	for amount: float in [-1.0, 0.0, NAN, INF, 3.0, 6.0]:
		check(not InventoryTransferService.transfer(source, target, stack, amount).is_empty(), "Invalid quantity or capacity is rejected")
	check(source.inventory().get_amount("coal") == 5 and target.inventory().amount_used == 0 and notifications[0] == 0, "Rejected transfers leave stock and signals unchanged")
	check(not InventoryTransferService.validate(source, source, stack, 1).is_empty(), "Same inventory is rejected")
	(target._anchor.get_ref() as Node3D).position.x = 21
	check(InventoryTransferService.maximum(source, target, stack) == 0, "Distant inventories cannot transfer")
	(target._anchor.get_ref() as Node3D).position.x = 0
	target.component().accepted_categories = [BaseGoodsType.ResourceCategory.PASSENGER]
	check(not InventoryTransferService.validate(source, target, stack, 1).is_empty(), "Unsupported resource category is rejected")
	target.component().accepted_categories.clear()

	check(InventoryTransferService.maximum(source, target, stack) == 2, "Max accounts for free capacity")
	check(InventoryTransferService.transfer(source, target, stack, 2).is_empty(), "Valid cargo transfer succeeds")
	check(source.inventory().get_amount("coal") == 3 and target.inventory().get_amount("coal") == 2, "Cargo is conserved")
	check(notifications[0] == 1 and target.inventory().amount_used == 2, "Successful transfer updates totals and emits once")
	(target._anchor.get_ref() as Node3D).free()
	check(not target.available() and not InventoryTransferService.validate(source, target, stack, 1).is_empty(), "Freed components become unavailable")
	return true

# Destinations are physical stop IDs; moving one batch must never merge other goals.
func test_passengers() -> bool:
	var source: InventoryEndpoint = endpoint("WaitingRoom")
	var target: InventoryEndpoint = endpoint("Bus", 4)
	source.inventory().change_stack(&"passenger", 201, 3)
	source.inventory().change_stack(&"passenger", 202, 2)
	source.inventory().add_good_of(&"passenger")
	var batch := InventoryStack.new(&"passenger", 3, 201)
	check(source.inventory().stacks(true).size() == 3 and source.inventory().stacks(false).is_empty(), "Passenger goals and unassigned counts form distinct rows")
	check(not InventoryTransferService.transfer(source, target, batch, 0.5).is_empty(), "Fractional passengers are rejected")
	check(InventoryTransferService.transfer(source, target, batch, 2).is_empty(), "Selected passenger batch transfers")
	check(source.inventory().stack_amount(&"passenger", 201) == 1 and target.inventory().stack_amount(&"passenger", 201) == 2, "Destination follows the transferred batch")
	check(source.inventory().stack_amount(&"passenger", 202) == 2 and source.inventory().stack_amount(&"passenger") == 1, "Other destinations and unassigned passengers stay untouched")
	check(source.inventory().storage.total_passengers + target.inventory().storage.total_passengers == 6, "Aggregate passenger totals remain conserved")
	check(not source.inventory().remove_goods_amount(GoodsAmount.new("passenger", 2)), "Legacy removal cannot consume assigned batches")

	var path := "/tmp/hinterland_inventory_transfer_roundtrip.tres"
	check(ResourceSaver.save(source.inventory(), path) == OK, "Destination groups can be saved as resource data")
	var restored: GoodsInventory = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(restored.stack_amount(&"passenger", 202) == 2 and restored.stack_amount(&"passenger") == 1, "Destination groups survive resource round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return true

# Exercise the actual GAZ picker, both transfer buttons, filters, tabs and modal cleanup.
func test_vehicle_dialog() -> bool:
	var previous_player: PlayerHead3D = GlobalState.player
	var previous_camera: Camera3D = GlobalState.active_cam
	var previous_dialog: GameDialog = UiState.current_diag
	var previous_blocked: bool = UiState.movement_blocked
	var previous_mouse: Input.MouseMode = Input.mouse_mode
	var player: Node3D = load("res://scenes/subscenes/player.tscn").instantiate()
	host.add_child(player)
	var walking: BasicFpsPlayer = player.get_node("Player")
	var previous_process: int = walking.process_mode
	var gaz := RoadVehicle3D.of("gaz_aa_truck")
	gaz.freeze = true
	host.add_child(gaz)
	GlobalState.player.in_road_vehicle = gaz
	var items: Array[InventoryEndpoint] = InventorySelectionService.new().discover()
	check(not items.is_empty() and items[0].inventory() == gaz.get_inventory(), "Occupied GAZ is discovered before the player bag")
	check(gaz.get_inventory().amount_max == 4 and not gaz.inventory_component.accepts(&"passenger"), "GAZ uses its freight-only catalog capacity")
	check(_test_nearby_stops() == true, "Nearby stop discovery completes")
	var stop: InventoryEndpoint = endpoint("DepotStock", 100)
	stop.kind = InventoryEndpoint.Kind.STOP
	stop.inventory().add_goods_amount(GoodsAmount.new("lumber", 8))
	stop.inventory().change_stack(&"passenger", 201, 3)
	items.append(stop)

	var dialog: InventoryTransferDialog = load("res://scenes/ui/dialogs/transfer_inventory/transfer_inventory_dialog.tscn").instantiate()
	dialog.available_endpoints = items
	host.add_child(dialog)
	await tree.process_frame
	await tree.process_frame
	check(dialog._left.endpoint.inventory() == gaz.get_inventory() and dialog._right.endpoint == stop, "Dialog defaults to occupied truck and a stop")
	check(dialog._tabs.current_tab == 1 and dialog._right._table.columns == 2, "Freight vehicle starts on Cargo")
	check(dialog._quantity.value == 1, "Cargo quantity defaults to exactly one unit")
	check(walking.process_mode == Node.PROCESS_MODE_DISABLED and UiState.movement_blocked, "Inventory dialog suspends walking")

	var row: TreeItem = dialog._right._table.get_root().get_first_child()
	check(row != null and row.get_icon(0) != null, "Cargo rows display existing resource icons")
	row.select(0)
	dialog._right._on_row_selected()
	dialog._maximum.pressed.emit()
	check(dialog._quantity.value == 4 and not dialog._move_left.disabled, "Max selects the truck's remaining capacity")
	dialog._move_left.pressed.emit()
	await tree.process_frame
	await tree.process_frame
	check(gaz.get_inventory().get_amount("lumber") == 4 and stop.inventory().get_amount("lumber") == 4, "Move-left button loads the GAZ")
	row = dialog._left._table.get_root().get_first_child()
	row.select(0)
	dialog._left._on_row_selected()
	dialog._quantity.value = 1
	dialog._move_right.pressed.emit()
	await tree.process_frame
	check(gaz.get_inventory().get_amount("lumber") == 3 and stop.inventory().get_amount("lumber") == 5, "Move-right button unloads the GAZ")

	dialog._right._search.text = "missing"
	dialog._right._refresh()
	check(dialog._right._table.get_root().get_first_child() == null, "Search filters nonmatching resources")
	dialog._right._search.text = ""
	dialog._tabs._buttons[0].pressed.emit()
	check(dialog._right._table.columns == 3 and dialog._quantity.step == 1, "Passenger tab shows destination column and whole quantities")
	row = dialog._right._table.get_root().get_first_child()
	check(row.get_metadata(0).destination_stop == 201, "Passenger row retains its physical destination")

	dialog.close_all()
	await tree.process_frame
	check(UiState.current_diag == null and walking.process_mode == previous_process, "Closing restores player processing and clears dialog")
	check(UiState.movement_blocked == previous_blocked and Input.mouse_mode == previous_mouse, "Closing restores exact input state")
	player.free()
	gaz.free()
	GlobalState.player = previous_player
	GlobalState.active_cam = previous_camera
	UiState.current_diag = previous_dialog
	return true

# Nearby road stops have separate identities even when they share a name.
func _test_nearby_stops() -> bool:
	var previous_stops: RoadStopsLoader = Managers.road_stops
	var previous_interchanges: InterchangesLoader = Managers.interchanges
	var stops := RoadStopsLoader.new()
	var interchanges := InterchangesLoader.new()
	host.add_child(stops)
	host.add_child(interchanges)
	Managers.road_stops = stops
	Managers.interchanges = interchanges
	var records: Array[RoadStationData] = []
	for id: int in [201, 202, 203]:
		var record := RoadStationData.new(id, "Market")
		record.position.x = 5 if id != 203 else 30
		record.hide_building = true
		var view: BusStop3D = load("res://scenes/subscenes/infr/station/bus_stop_3d.tscn").instantiate()
		view.station = record
		stops.add_child(view)
		stops.containers_by_num[id] = view
		interchanges.stops_by_num[id] = record
		records.append(record)
	var found: Array[InventoryEndpoint] = InventorySelectionService.new().discover()
	var stop_count: int = 0
	for item: InventoryEndpoint in found:
		if item.kind == InventoryEndpoint.Kind.STOP:
			stop_count += 1
	check(stop_count == 2, "Discovery includes both nearby physical road stops and excludes distant stops")
	check(InventoryPresentation.destination(201) != InventoryPresentation.destination(202), "Shared station names retain distinct physical stop labels")
	stops.free()
	interchanges.free()
	for record: RoadStationData in records:
		record.connections.parent = null
	Managers.road_stops = previous_stops
	Managers.interchanges = previous_interchanges
	return true
