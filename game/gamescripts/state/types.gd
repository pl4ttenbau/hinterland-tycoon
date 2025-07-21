extends Node

@export var maps: Array[MapData] = []

@export var infr_types: Array[InfrType]
@export var industry_types: Array[IndustryType]
@export var res_bld_types: Array[ResBldType]

# == GETTER METHODS ==
func get_infr_type(key: String) -> InfrType:
	for infr_type: InfrType in self.infr_types:
		if infr_type.key == key: return infr_type
	Loggie.error("InfrType \"%s\" could not be found" % key)
	return null

func get_rnd_res_bld() -> ResBldType:
	randomize()
	var rnd_i: int = randi_range(0, self.res_bld_types.size() -1)
	return self.res_bld_types.get(rnd_i)
	
func get_res_bld_type(_key: String) -> ResBldType:
	for res_bld_type: ResBldType in self.res_bld_types:
		if res_bld_type.key == _key: return res_bld_type
	return null

func get_ind_type(key: String) -> IndustryType:
	for found_type: IndustryType in self.industry_types:
		if found_type.key == key: return found_type
	Loggie.error("IndustryType \"%s\" could not be found" % key)
	return null
