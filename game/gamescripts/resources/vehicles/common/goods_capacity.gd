class_name GoodsCapacity extends Resource

@export var goods_cat: BaseGoodsType.ResourceCategory

@export var amount: int

static func of(_amount: int, _cat: BaseGoodsType.ResourceCategory) -> GoodsCapacity:
	var inst := GoodsCapacity.new()
	inst.amount = _amount
	inst.goods_cat = _cat
	return inst
	
static func of_json(_capacity_dict: Dictionary) -> GoodsCapacity:
	var _amount: int = _capacity_dict.get("amount") as int
	var cat_str: String = _capacity_dict.get("cat")
	return GoodsCapacity.of(_amount, BaseGoodsType.res_cat_str_to_enum(cat_str))
