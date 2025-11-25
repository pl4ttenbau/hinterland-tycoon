extends Node

@export var resource_types: Dictionary

@export var infr_types: Array[InfrType]
@export var industry_types: Array[IndustryType]
@export var res_bld_type_store: ResBldTypeStore = ResBldTypeStore.new()
@export var vehicle_types: Array[RailVehicleType]

# == GETTER METHODS ==
#region Infrastructure
func get_infr_type(key: String) -> InfrType:
	for infr_type: InfrType in self.infr_types:
		if infr_type.key == key: return infr_type
	Loggie.error("InfrType \"%s\" could not be found" % key)
	return null
#endregion

#region Residential Buiildings
func get_rnd_placable_res_bld() -> ResBldType:
	for i in range(5):
		var rnd_res_type: ResBldType = self.res_bld_store.get_random()
		if rnd_res_type.block_auto_placement == false:
			return rnd_res_type
	return null

func get_res_bld_type(_key: String) -> ResBldType:
	return self.res_bld_store.get_by_key(_key)
#endregion

#region Industry Types
func get_ind_type(key: String) -> IndustryType:
	for found_type: IndustryType in self.industry_types:
		if found_type.key == key: return found_type
	Loggie.error("IndustryType \"%s\" could not be found" % key)
	return null
#endregion
