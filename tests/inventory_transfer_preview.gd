extends Node3D

# A self-closing visual fixture with real goods icons and distinct physical-stop goals.
func _ready() -> void:
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 900)
	get_tree().create_timer(10).timeout.connect(func(): get_tree().quit(1))
	_preview.call_deferred()

func _preview() -> void:
	var truck := RoadVehicle3D.of("gaz_aa_truck")
	truck.freeze = true
	add_child(truck)
	truck.get_inventory().add_goods_amount(GoodsAmount.new("lumber", 2))
	var station := Node3D.new()
	station.name = "Sawmill loading station"
	var inventory := InventoryContainer.new()
	inventory.capacity_override = 60
	station.add_child(inventory)
	add_child(station)
	for key: String in ["lumber", "coal", "iron", "mail", "tourist", "soldier"]:
		if GameTypes.resource_types.has(key):
			inventory.get_inventory().add_goods_amount(GoodsAmount.new(key, 4))
	inventory.get_inventory().change_stack(&"passenger", 17, 12)
	inventory.get_inventory().change_stack(&"passenger", 26, 7)
	var dialog: InventoryTransferDialog = load("res://scenes/ui/dialogs/transfer_inventory/transfer_inventory_dialog.tscn").instantiate()
	dialog.available_endpoints = [InventoryEndpoint.from_node(truck, "GAZ-AA truck #1"), InventoryEndpoint.from_node(station, "Sawmill loading station")]
	add_child(dialog)

	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/inventory-cargo.png")
	dialog._tabs.current_tab = 0
	await get_tree().create_timer(1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/inventory-passengers.png")
	dialog.close_all()
	await get_tree().process_frame
	get_tree().quit()
