## child of a real iventory
## contains an amount of goods, but no higher-leven functions to interact with
class_name BaseGoodsStorage extends Resource

@export var inventory_dict: Dictionary = {}

@export var max_storage: int = DEFAULT_MAX_STORAGE
@export var current_storage: int = 0

static var DEFAULT_MAX_STORAGE = 150.0

func _set_amount(good_type_key: String, amount: int):
	self.inventory_dict.set(good_type_key, amount)

func get_amount(goods_type_key: String) -> int:
	if ! self.has_any(goods_type_key): return 0
	return self.inventory_dict.get(goods_type_key)
	
func change_amount(goods_type_key: String, amount_modifier: int) -> int:
	var new_amount: int = self.get_amount(goods_type_key) + amount_modifier
	self._set_amount(goods_type_key, new_amount)
	# update currently stored var
	self.current_storage += amount_modifier
	return new_amount
	
func has_any(goods_type_key: String) -> bool:
	return self.inventory_dict.has(goods_type_key)
