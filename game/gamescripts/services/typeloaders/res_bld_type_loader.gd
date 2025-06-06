class_name ResBldTypeLoader extends RefCounted

static func _dict_to_obj(_bld_type_data: Dictionary) -> Array[ResBldType]:
	return [
		ResBldType.new("town_house_1", "Town House", 8),
		ResBldType.new("village_house_1", "Village House", 5)
	]
