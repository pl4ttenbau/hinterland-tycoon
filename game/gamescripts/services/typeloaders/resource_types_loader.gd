@icon("res://assets/icons/icon_good_white.png")
class_name ResourceTypesLoader extends AbstractGameTypeLoader

@export var types_by_key: Dictionary

func _init():
	GameTypes.resource_types = self.make_types()
	
func make_types_list() -> Array[BaseResourceType]:
	return [
		BaseResourceType.new("passenger", BaseResourceType.ResourceCategory.PASSENGER),
		BaseResourceType.new("grains", BaseResourceType.ResourceCategory.FREIGHT),
		BaseResourceType.new("bread", BaseResourceType.ResourceCategory.FREIGHT),
		BaseResourceType.new("lumber", BaseResourceType.ResourceCategory.FREIGHT),
		BaseResourceType.new("coal", BaseResourceType.ResourceCategory.FREIGHT),
		BaseResourceType.new("iron", BaseResourceType.ResourceCategory.FREIGHT)
	]

func make_types() -> Dictionary:
	self.types_by_key = self.sort_types_by_key(self.make_types_list())
	return self.types_by_key
	
func sort_types_by_key(types_list: Array[BaseResourceType]) -> Dictionary:
	var dict: Dictionary = {}
	for res_type: BaseResourceType in types_list:
		dict.set(res_type.key, res_type)
	return dict
