@icon("res://assets/icons/icon_good_white.png")
class_name GoodsInventory extends Resource

signal resource_change()

@export var storage: BaseGoodsStorage

@export var total_amount: int:
	get(): return self.storage.current_storage

func _init() -> void:
	if !self.storage:
		self.storage = BaseGoodsStorage.new()

#region Add Or Remove
func add_good_of(res_type_key: StringName) -> SpawnedGood:
	var spawned_res := SpawnedGood.new(res_type_key, 1)
	if spawned_res.is_valid:
		self.add_spawned_good(spawned_res)
		return spawned_res
	return null
	
func add_spawned_good(spawned_res: SpawnedGood):
	self.storage.change_amount(spawned_res.res_type.key, spawned_res.amount)
	var amount_now: float = self.storage.get_amount(spawned_res.res_type.key)
	Loggie.info("Has now %f" % amount_now)
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

func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		self.storage = null
