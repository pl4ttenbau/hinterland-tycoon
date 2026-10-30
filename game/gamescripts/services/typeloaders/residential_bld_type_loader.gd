class_name ResidentialBldTypeLoader extends AbstractGameTypeLoader

static func get_bld_types() -> Array[ResBldType]:
	return [
		ResBldType.new("wooden_shack", "Shack", 3),
		ResBldType.new("village_house_2", "Village House", 6),
		ResBldType.new("village_house_3", "Village House", 4),
		ResBldType.new("city_house_1", "City House", 16, true),
		ResBldType.new("city_house_2", "City House", 8),
		ResBldType.new("city_house_3", "City House", 10),
		ResBldType.new("city_house_4", "City House", 8),
		ResBldType.new("city_corner_house", "City House", 8),
		ResBldType.new("old_city_house_1", "City House", 6),
		ResBldType.new("old_city_giebelhaus_1", "Giebelhaus", 9),
		ResBldType.new("old_city_house_speicher", "Speicher", 8),
		ResBldType.new("old_city_house_bakery", "Speicher", 6),
		ResBldType.new("half_timbered_1", "Tudor House", 6),
		ResBldType.new("half_timbered_2", "Tudor House", 8),
		ResBldType.new("half_timbered_barn", "Tudor Barn", 5),
		ResBldType.new("harz_house_1", "Harz House", 8),
		ResBldType.new("ddr_ew_65", "Village House", 4),
		ResBldType.new("city_manor", "City Manor", 15, true),
		# northern
		ResBldType.new("northern_german_house", "Tudor Cottage", 12),
		ResBldType.new("vitte_fischerhaus", "Fishing House", 6),
		ResBldType.new("thatched_house_1", "Fishing House", 4),
		# polish
		ResBldType.new("polish_house_1", "Polish House", 3),
		ResBldType.new("polish_house_2", "Polish House", 4),
		ResBldType.new("polish_house_3", "Polish House", 6),
		ResBldType.new("polish_house_4", "Polish House", 4),
		ResBldType.new("polish_house_5", "Polish House", 12),
		# Russian
		ResBldType.new("ru_village_hut_1", "Isba", 5),
		ResBldType.new("ru_village_hut_2", "Isba", 6),
		ResBldType.new("ru_village_hut_3", "Isba", 3),
		ResBldType.new("ru_village_hut_4", "Isba", 4),
		ResBldType.new("ru_village_hut_5", "Isba", 5),
		ResBldType.new("ru_small_house_1", "Barracks", 15),
		ResBldType.new("ru_small_house_2", "Barracks", 20),
		ResBldType.new("ru_kruschovka_1", "Kruschovka", 40),
		ResBldType.new("ru_stalinka_1", "Stalinka", 55)
	]
	
func load_types() -> Error:
	var definitions: Array[ResBldType] = self.get_bld_types()
	var error: Error = validate_keys(definitions)
	if error != OK:
		return error
	GameTypes.res_bld_type_store = ResBldTypeStore.new()
	for definition: ResBldType in definitions:
		GameTypes.res_bld_type_store.add(definition)
	self.loading_finished.emit()
	return OK

func get_rnd() -> ResBldType:
	return GameTypes.res_bld_type_store.get_random()
