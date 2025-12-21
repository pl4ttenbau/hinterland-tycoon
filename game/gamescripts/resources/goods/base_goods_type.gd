@icon("res://assets/icons/icon_good_white.png")
class_name BaseGoodsType extends Resource

enum ResourceCategory {PASSENGER, MAIL, FREIGHT}

@export var key: StringName
@export var res_cat: ResourceCategory

func _init(_key: StringName, _cat: BaseGoodsType.ResourceCategory):
	self.key = _key
	self.res_cat = _cat

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
	else: return ResourceCategory.FREIGHT
#endregion
