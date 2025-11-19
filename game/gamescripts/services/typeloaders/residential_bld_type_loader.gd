class_name ResidentialBldTypeLoader extends AbstractGameTypeLoader

@export var types: Array[ResBldType]
@export var storage: ResBldTypeStore = ResBldTypeStore.new()

func _init():
	self.load_types()

static func _dict_to_obj(_bld_type_data: Dictionary) -> Array[ResBldType]:
	return [
		ResBldType.new("wooden_shack", "Shack", 3),
		ResBldType.new("polish_house_1", "Polish House", 3),
		ResBldType.new("polish_house_2", "Polish House", 4),
		ResBldType.new("polish_house_3", "Polish House", 6),
		ResBldType.new("polish_house_4", "Polish House", 4),
		ResBldType.new("polish_house_5", "Polish House", 12),
		ResBldType.new("thatched_house_1", "Polish House", 4),
		ResBldType.new("village_house_2", "Village House", 6),
		ResBldType.new("village_house_3", "Village House", 4),
		ResBldType.new("city_house_2", "City House", 8),
		ResBldType.new("city_corner_house", "City House", 8),
		ResBldType.new("half_timbered_1", "Tudor House", 6),
		ResBldType.new("half_timbered_barn", "Tudor Barn", 5),
		ResBldType.new("northern_german_house", "Tudor Cottage", 12),
		ResBldType.new("city_manor", "City Manor", 15, true)
	]
	
func load_types() -> void:
	if  self.storage.is_empty():
		for res_bld_type: ResBldType in self._dict_to_obj(Dictionary()):
			self.storage.add(res_bld_type)
		SignalBus.res_bld_types_loaded.emit()
		Loggie.info("Loading ResBldTypes... finished.")

func get_rnd() -> ResBldType:
	var bld_types: Array[ResBldType] = GameTypes.res_bld_types
	randomize()
	return bld_types.get(randi_range(0, bld_types.size() -1))
