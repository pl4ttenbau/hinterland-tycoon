class_name InventoryEntity3D extends GameEntity3D

signal inventory_connected(inv_obj: GoodsInventory)

var cached_inventory: GoodsInventory

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
	var named_child = self.find_child("Inventory")
	if named_child && named_child is InventoryContainer:
		return named_child.inventory
	## look for any children of GoodsInventory type
	for any_child in self.get_children():
		if any_child is InventoryContainer:
			return any_child.inventory
	return null
#endregion

func _exit_tree() -> void:
	self.cached_inventory = null
