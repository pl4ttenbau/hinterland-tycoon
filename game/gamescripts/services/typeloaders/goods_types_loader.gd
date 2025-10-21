@icon("res://assets/icons/icon_good_white.png")
class_name GoodsTypesLoader extends AbstractGameTypeLoader

@export var types_by_key: Dictionary

func _init():
	GameTypes.resource_types = self.make_types()
	
func make_types_list() -> Array[BaseGoodsType]:
	return [
		BaseGoodsType.new("passenger", BaseGoodsType.ResourceCategory.PASSENGER),
		BaseGoodsType.new("tourist", BaseGoodsType.ResourceCategory.PASSENGER),
		BaseGoodsType.new("soldier", BaseGoodsType.ResourceCategory.PASSENGER),

		BaseGoodsType.new("grains", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("beets", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("meat", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("bread", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("sugar", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("alcohol", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("fertilizer", BaseGoodsType.ResourceCategory.FREIGHT),

		BaseGoodsType.new("lumber", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("boards", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("bricks", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("gravel", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("concrete", BaseGoodsType.ResourceCategory.FREIGHT),

		BaseGoodsType.new("coal", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("ore", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("ingots", BaseGoodsType.ResourceCategory.FREIGHT),

		BaseGoodsType.new("paper", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("motors", BaseGoodsType.ResourceCategory.FREIGHT),
		BaseGoodsType.new("rail_tracks", BaseGoodsType.ResourceCategory.FREIGHT),
	]

func make_types() -> Dictionary:
	self.types_by_key = self.sort_types_by_key(self.make_types_list())
	return self.types_by_key
	
func sort_types_by_key(types_list: Array[BaseGoodsType]) -> Dictionary:
	var dict: Dictionary = {}
	for res_type: BaseGoodsType in types_list:
		dict.set(res_type.key, res_type)
	return dict
