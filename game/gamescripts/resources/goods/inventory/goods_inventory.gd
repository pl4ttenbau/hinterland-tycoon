@icon("res://assets/icons/icon_good_white.png")
class_name GoodsInventory extends Resource

signal goods_change()

@export var storage: BaseGoodsStorage

@export var amount_used: float

@export var amount_max: float

func _init() -> void:
	self.resource_local_to_scene = true
	# create BaseStorage child if not already done
	if !self.storage:
		self.storage = BaseGoodsStorage.new()
		if self.amount_max && self.amount_max > 0:
			self.storage.max_storage = amount_max
	# connect to change signal
	self.goods_change.connect(Callable(self, "_on_goods_changed"))

#region Add Or Remove
func add_good_of(res_type_key: StringName):
	var amount_dto := GoodsAmount.new(res_type_key, 1)
	self.add_goods_amount(amount_dto)

func add_goods_amount(goods_amount: GoodsAmount):
	self.storage.change_amount(goods_amount.res_key, goods_amount.amount)
	self.goods_change.emit()

func remove_goods_amount(goods_amount: GoodsAmount):
	var change_amount: float = -1 * goods_amount.amount
	self.storage.change_amount(goods_amount.res_key, change_amount)
	self.goods_change.emit()
#endregion

#region Getters
func as_goods_amount_list() -> Array[GoodsAmount]:
	var amount_dto_list: Array[GoodsAmount] = []
	for res_key: String in self.storage.get_res_key_list():
		var amount_dto = GoodsAmount.new(res_key, self.get_amount(res_key))
		amount_dto_list.append(amount_dto)
	return amount_dto_list

func get_amount(res_type_key: String) -> float:
	return self.storage.get_amount(res_type_key)
#endregion

#region Amount Checking
func has_any(res_type_key: String) -> bool:
	return self.storage.has_any(res_type_key)
	
func has_enough(amount_dto: GoodsAmount) -> bool:
	if ! amount_dto.res_key: return false
	var amount_left: float = self.get_amount(amount_dto.res_key)
	return amount_left >= amount_dto.amount

func can_take(amount_dto: GoodsAmount):
	var stored_after_added: float = self.amount_used + amount_dto.amount
	return stored_after_added <= self.amount_max
#endregion

#region Callbacks
func _on_goods_changed():
	if !self.storage:
		Loggie.error("BaseResourceStorage not added as a child!")
		return
	self.amount_used = self.storage.current_storage
#endregion
