class_name InventoryEntity3D extends GameEntity3D

signal inventory_connected(inv_obj: GoodsInventory)

@export var cached_inventory: GoodsInventory

func get_inventory() -> GoodsInventory:
	if self.cached_inventory:
		return self.cached_inventory
	# find and cache
	var found: GoodsInventory = self._find_inventory()
	if found:
		self.cached_inventory = found
		self.inventory_connected.emit(found)
	return found

#region Initialization
func _ready() -> void:
	if !self.cached_inventory:
		self._find_inventory()

func _find_inventory() -> GoodsInventory:
	var component: InventoryContainer = InventoryContainer.find_on(self)
	return component.get_inventory() if component != null else null
#endregion

func _exit_tree() -> void:
	self.cached_inventory = null
