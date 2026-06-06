## child of a real iventory
## contains an amount of goods, but no higher-leven functions to interact with
class_name BaseGoodsStorage extends Resource

@export var inventory_dict: Dictionary = Dictionary()

@export var max_storage: float
@export var current_storage: float = 0

@export var total_passengers: float
@export var total_cargo: float

static var DEFAULT_MAX_STORAGE = 150.0

func _init() -> void:
	self.max_storage = DEFAULT_MAX_STORAGE

func get_amount(goods_type_key: String) -> float:
	if ! self.has_any(goods_type_key): return 0
	return self.inventory_dict.get(goods_type_key)
		
func change_amount(goods_type_key: String, amount_modifier: float) -> float:
	var new_amount: float = self.get_amount(goods_type_key) + amount_modifier
	self._set_amount(goods_type_key, new_amount)
	# update currently stored var & cached passenger/cargo storage
	self.current_storage += amount_modifier
	self._change_amount_passengers_cargo(goods_type_key, amount_modifier)
	return new_amount

## update total amount of passengers & cargo
func _change_amount_passengers_cargo(goods_type_key: String, amount_modifier: float):
	var goods_type: BaseGoodsType = BaseGoodsType.get_by_key(goods_type_key)
	if goods_type_key:
		if goods_type.is_passenger():
			self.total_passengers += amount_modifier
		elif goods_type.is_cargo():
			self.total_cargo += amount_modifier

#region Internal Goods Changing
func _set_amount(good_type_key: String, amount: float):
	self.inventory_dict.set(good_type_key, amount)
#endregion

#region Getters & Converters
func has_any(goods_type_key: String) -> bool:
	return self.inventory_dict.has(goods_type_key)

func get_res_key_list() -> Array[String]:
	var res_key_list: Array[String] = []
	for res_key: String in self.inventory_dict.keys():
		res_key_list.append(res_key)
	return res_key_list
#endregion
