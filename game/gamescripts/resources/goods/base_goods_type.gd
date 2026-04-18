@icon("res://assets/icons/icon_good_white.png")
class_name BaseGoodsType extends Resource

enum ResourceCategory {PASSENGER, MAIL, FREIGHT, LIQUID, AGGREGATE}

@export var key: StringName
@export var res_cat: ResourceCategory

func _init(_key: StringName, _cat: BaseGoodsType.ResourceCategory):
	self.key = _key
	self.res_cat = _cat

#region Getters
func get_display_text() -> String:
	return self.key.capitalize()
#endregion

#region Static Getters
static func get_by_key(_key: StringName) -> BaseGoodsType:
	var found := GameTypes.resource_types.get(_key) as BaseGoodsType
	if ! found:
		Loggie.warn("cannot get resource type \"%s\"" % _key)
		return null
	return found
	
static func get_all() -> Array[BaseGoodsType]:
	var all_good_types: Array[BaseGoodsType] = []
	for raw_good_type in GameTypes.resource_types.values():
		if raw_good_type is BaseGoodsType:
			all_good_types.append(raw_good_type as BaseGoodsType)
	return all_good_types
#endregion

#region ResourceCategory
static func res_cat_str_to_enum(res_cat_str: String) -> ResourceCategory:
	if res_cat_str == "PASSENGER": return ResourceCategory.PASSENGER
	elif res_cat_str == "MAIL": return ResourceCategory.MAIL
	elif res_cat_str == "AGGREGATE": return ResourceCategory.AGGREGATE
	elif res_cat_str == "LIQUID": return ResourceCategory.LIQUID
	else: return ResourceCategory.FREIGHT

static func get_cat_image_path(res_cat_str: String) -> String:
	if res_cat_str == "PASSENGER": return "res://assets/ui/images/goods_type/passenger_storage.png"
	elif res_cat_str == "MAIL": return "res://assets/ui/images/goods_type/luggage_storage.png"
	elif res_cat_str == "AGGREGATE": return "res://assets/ui/images/goods_type/aggregate_storage.png"
	elif res_cat_str == "LIQUID": return "res://assets/ui/images/goods_type/liquid_storage.png"
	else: return "res://assets/ui/images/goods_type/box_storage.png"

#endregion
