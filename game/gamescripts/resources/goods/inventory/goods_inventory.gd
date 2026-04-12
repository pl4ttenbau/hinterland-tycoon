@icon("res://assets/icons/icon_good_white.png")
class_name GoodsInventory extends GameObject

signal resource_change()

@export var storage: BaseGoodsStorage = BaseGoodsStorage.new()

@export var total_amount: int:
	get(): return self.storage.current_storage

#region Add Or Remove
func add_good_of(res_type_key: StringName) -> SpawnedGood:
	var spawned_res := SpawnedGood.new(res_type_key, 1)
	self.add_spawned_good(spawned_res)
	return spawned_res
	
func add_spawned_good(spawned_res: SpawnedGood):
	self.storage.change_amount(spawned_res.res_type.key, spawned_res.amount)
	spawned_res.current_location = self
	self.resource_change.emit()

func remove_spawned_good(spawned_res: SpawnedGood):
	var change_amount: int = -1 * spawned_res.amount
	self.storage.change_amount(spawned_res.res_type.key, change_amount)
	self.resource_change.emit()
#endregion

#region Getters
func get_amount(res_type_key: String) -> int:
	return self.storage.get_amount(res_type_key)
	
func has_any(res_type_key: String) -> bool:
	return self.storage.has_any(res_type_key)
	
func has_enough(spawned_res: SpawnedGood) -> bool:
	if ! spawned_res.res_type || ! spawned_res.res_type.key: return false
	var amount_left: int = self.get_amount(spawned_res.res_type.key)
	return amount_left >= spawned_res.amount
#endregion
