@icon("res://assets/icons/icon_good_white.png")
class_name ResourceTypesLoader extends AbstractGameTypeLoader

@export var types_by_key: Dictionary

func _init():
	GameTypes.resource_types = self.make_types()

func make_types() -> Dictionary:
	var types_list: Array[BaseResourceType] = [
		BaseResourceType.new("passenger", BaseResourceType.ResourceCategory.PASSENGER),
		BaseResourceType.new("grains", BaseResourceType.ResourceCategory.FREIGHT),
		BaseResourceType.new("bread", BaseResourceType.ResourceCategory.FREIGHT),
		BaseResourceType.new("lumber", BaseResourceType.ResourceCategory.FREIGHT),
		BaseResourceType.new("coal", BaseResourceType.ResourceCategory.FREIGHT),
		BaseResourceType.new("iron", BaseResourceType.ResourceCategory.FREIGHT)
	]
	var types_by_key: Dictionary = self.sort_types_by_key(types_list)
	return types_by_key
	
func sort_types_by_key(types_list: Array[BaseResourceType]) -> Dictionary:
	var dict: Dictionary = {}
	for res_type: BaseResourceType in types_list:
		var key: StringName = res_type.key
		dict.set(key, res_type)
	return dict
