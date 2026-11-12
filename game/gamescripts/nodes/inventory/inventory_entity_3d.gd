@tool
class_name InventoryEntity3D extends GameEntity3D

signal inventory_connected(inv_obj: GoodsInventory)

@export var cached_inventory: GoodsInventory

func get_inventory() -> GoodsInventory:
	# Access can change when an entity is linked to an interchange. Keep the
	# cache for its own inventory so it remains available if it is unlinked.
	var shared_inventory: GoodsInventory = get_shared_inventory()
	if shared_inventory != null:
		return shared_inventory
	if self.cached_inventory:
		return self.cached_inventory
	# find and cache
	var found: GoodsInventory = self._find_inventory()
	if found:
		self.cached_inventory = found
		self.inventory_connected.emit(found)
	return found

## Override when this view is an access point for another entity's inventory.
func get_shared_inventory() -> GoodsInventory:
	return null

#region Initialization
func _ready() -> void:
	if not Engine.is_editor_hint():
		get_inventory()

func _find_inventory() -> GoodsInventory:
	var component: InventoryContainer = InventoryContainer.find_on(self)
	return component.get_inventory() if component != null else null
#endregion

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		self.cached_inventory = null
