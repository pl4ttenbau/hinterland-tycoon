## Reusable inventory component. Attach to any entity; no entity inheritance is required.
@icon("res://assets/icons/inventory/inventory_container.svg")
class_name InventoryContainer extends Node

@export var inventory: GoodsInventory
## -1 uses the inventory resource's existing capacity. Zero explicitly accepts no stock.
@export var capacity_override: float = -1
## Empty accepts all categories; vehicles can restrict their supported cargo class.
@export var accepted_categories: Array[BaseGoodsType.ResourceCategory] = []
@export var display_name: String = ""

func _enter_tree() -> void:
	get_inventory()

func get_inventory() -> GoodsInventory:
	var view := get_parent() as InventoryEntity3D
	if view != null:
		var shared_inventory: GoodsInventory = view.get_shared_inventory()
		if shared_inventory != null:
			return shared_inventory
	if inventory == null:
		inventory = GoodsInventory.new()
		inventory.amount_max = BaseGoodsStorage.DEFAULT_MAX_STORAGE
	if capacity_override >= 0:
		inventory.amount_max = capacity_override
	inventory.storage.max_storage = inventory.amount_max
	return inventory

func accepts(key: StringName) -> bool:
	var good: BaseGoodsType = GameTypes.resource_types.get(key)
	return good != null and (accepted_categories.is_empty() or good.res_cat in accepted_categories)

func free_capacity() -> float:
	var data: GoodsInventory = get_inventory()
	return maxf(0, data.amount_max - data.storage.current_storage)

## Discover only a direct component, avoiding accidental access to a child vehicle's stock.
static func find_on(_owner: Node) -> InventoryContainer:
	if not is_instance_valid(_owner):
		return null
	if _owner is InventoryContainer:
		return _owner
	for child: Node in _owner.get_children():
		if child is InventoryContainer:
			return child
	return null
