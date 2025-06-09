class_name ResidentialBldTypeLoader extends Node

@export var types: Array[ResBldType]

func _init():
	GameTypes.res_bld_types = self.get_types()

static func _dict_to_obj(_bld_type_data: Dictionary) -> Array[ResBldType]:
	return [
		ResBldType.new("town_house_1", "Town House", 8),
		ResBldType.new("village_house_1", "Village House", 5),
		ResBldType.new("city_manor", "City Manor", 12)
	]
	
func get_types() -> Array[ResBldType]:
	if !self.types: self.types = _dict_to_obj(Dictionary())
	return self.types

func get_rnd() -> ResBldType:
	var bld_types: Array[ResBldType] = GameTypes.res_bld_types
	randomize()
	var rnd_i: int = randi_range(0, bld_types.size() -1)
	return bld_types.get(rnd_i)
