extends Node

@export var resource_types: Dictionary
@export var vehicle_types_dict: Dictionary

@export var infr_types: Array[InfrType]
@export var industry_types: Array[IndustryType]
@export var res_bld_type_store: ResBldTypeStore = ResBldTypeStore.new()
@export var vehicle_types: Array[VehicleTypeData]

# == GETTER METHODS ==
#region Infrastructure
func get_infr_type(key: String) -> InfrType:
	for infr_type: InfrType in self.infr_types:
		if infr_type.key == key: return infr_type
	Loggie.error("InfrType \"%s\" could not be found" % key)
	return null
#endregion

#region Residential Buildings
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

#region Vehicle Types
func set_and_sort_veh_types(veh_type_arr: Array[VehicleTypeData]):
	for veh_type: VehicleTypeData in veh_type_arr:
		self.vehicle_types_dict.set(veh_type.key, veh_type)

func get_veh_type(veh_type_key: String) -> VehicleTypeData:
	if self.vehicle_types_dict.has(veh_type_key):
		return self.vehicle_types_dict.get(veh_type_key)
	Loggie.warn("Cannot find VehicleType \"%s\"" % veh_type_key)
	return null
#endregion
