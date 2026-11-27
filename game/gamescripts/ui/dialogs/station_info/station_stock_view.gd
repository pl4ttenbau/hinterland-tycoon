## Live stock of the interchange (or the lone stop) with its capacity.
class_name StationStockView extends VBoxContainer

var _stop: AbstractStation
var _inventory: GoodsInventory

@onready var _capacity: Label = %Capacity
@onready var _list: ItemList = %InventoryList

func show_inventory(stop: AbstractStation) -> void:
	_disconnect_inventory()
	_stop = stop
	_inventory = stop.get_interchange_inventory()
	if _inventory == null:
		var view: InventoryEntity3D = stop.get_inventory_view()
		if is_instance_valid(view):
			_inventory = view.get_inventory()
	if _inventory != null:
		_inventory.goods_change.connect(_refresh)
	_refresh()

## Passenger batches show the city and station of their destination interchange.
func _refresh() -> void:
	_list.clear()
	if _inventory == null:
		_capacity.text = "Inventory unavailable"
		return
	var caption: String = "Shared stock" if _stop.interchange != null else "Stop stock"
	_capacity.text = "%s · %s / %s units" % [
		caption,
		InventoryPresentation.quantity(_inventory.storage.current_storage),
		InventoryPresentation.quantity(_inventory.amount_max),
	]
	for passengers: bool in [false, true]:
		for stack: InventoryStack in _inventory.stacks(passengers):
			var label: String = "%s × %s" % [InventoryPresentation.quantity(stack.amount), String(stack.good_key).capitalize()]
			if passengers:
				label += " · %s" % InventoryPresentation.destination(stack.destination_interchange)
			_list.add_item(label, InventoryPresentation.icon(stack.good_key), false)
	if _list.item_count == 0:
		_list.add_item("Empty", null, false)

func _disconnect_inventory() -> void:
	if _inventory != null and _inventory.goods_change.is_connected(_refresh):
		_inventory.goods_change.disconnect(_refresh)

func _exit_tree() -> void:
	_disconnect_inventory()
