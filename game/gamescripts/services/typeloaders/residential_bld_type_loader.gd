class_name ResidentialBldTypeLoader extends AbstractGameTypeLoader

@export var types: Array[ResBldType]

func _init():
	GameTypes.res_bld_types = self.get_types()

static func _dict_to_obj(_bld_type_data: Dictionary) -> Array[ResBldType]:
	return [
		ResBldType.new("polish_house_1", "Polish House", 3),
		ResBldType.new("polish_house_2", "Polish House", 4),
		ResBldType.new("polish_house_3", "Polish House", 6),
		ResBldType.new("polish_house_4", "Polish House", 4),
		ResBldType.new("polish_house_5", "Polish House", 12),
		ResBldType.new("village_house_2", "Village House", 6),
		ResBldType.new("village_house_3", "Village House", 4),
		# ResBldType.new("city_manor", "City Manor", 12)
	]
	
func get_types() -> Array[ResBldType]:
	if !self.types: self.types = _dict_to_obj(Dictionary())
	return self.types

func get_rnd() -> ResBldType:
	var bld_types: Array[ResBldType] = GameTypes.res_bld_types
	randomize()
	var rnd_i: int = randi_range(0, bld_types.size() -1)
	return bld_types.get(rnd_i)
