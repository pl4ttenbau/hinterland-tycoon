extends Node

@export var resource_types: Dictionary
@export var vehicle_types_dict: Dictionary

@export var infr_types: Array[InfrType]
var road_types: Dictionary[String, RoadType] = {}
var rail_types: Dictionary[String, RailType] = {}
var industry_buildings: Dictionary[String, IndustryBuildingType] = {}
@export var industry_types: Array[IndustryType]
@export var res_bld_type_store: ResBldTypeStore = ResBldTypeStore.new()
@export var vehicle_types: Array[VehicleTypeData]

## Definitions survive scene changes. Completion signals are emitted only once.
var is_initialized: bool = false
var is_initializing: bool = false

func ensure_initialized() -> Error:
	if self.is_initialized:
		return OK
	if self.is_initializing:
		return ERR_BUSY
	self.is_initializing = true
	self._clear_catalogs()
	# Goods must exist before industry recipes can be validated.
	var loaders: Array[AbstractGameTypeLoader] = [
		GoodsTypesLoader.new(), InfrTypesLoader.new(), IndustryTypeLoader.new(),
		ResidentialBldTypeLoader.new(), RailVehicleTypesLoader.new(), RoadVehicleTypesLoader.new()
	]
	var names: Array[StringName] = [&"goods", &"infrastructure", &"industries", &"residences", &"rail_vehicles", &"road_vehicles"]
	for index: int in range(loaders.size()):
		loaders[index].loading_finished.connect(self._on_type_loaded.bind(names[index]), CONNECT_ONE_SHOT)
		var error: Error = loaders[index].load_types()
		if error != OK:
			return self._fail_initialization(error)
	var error: Error = self._validate_references()
	if error != OK:
		return self._fail_initialization(error)
	self.is_initialized = true
	self.is_initializing = false
	SignalBus.res_bld_types_loaded.emit()
	SignalBus.all_types_initialized.emit()
	return OK

func _on_type_loaded(type_name: StringName) -> void:
	SignalBus.type_catalog_loaded.emit(type_name)

func _fail_initialization(error: Error) -> Error:
	self._clear_catalogs()
	self.is_initializing = false
	SignalBus.types_initialization_failed.emit(error)
	return error

func _clear_catalogs() -> void:
	self.resource_types.clear()
	self.infr_types.clear()
	self.road_types.clear()
	self.rail_types.clear()
	self.industry_buildings.clear()
	self.industry_types.clear()
	self.res_bld_type_store = ResBldTypeStore.new()
	self.vehicle_types.clear()
	self.vehicle_types_dict.clear()

func _validate_references() -> Error:
	for vehicle: VehicleTypeData in self.vehicle_types:
		if vehicle.usable_infr == null:
			push_error("Vehicle %s has no infrastructure definition" % vehicle.key)
			return ERR_INVALID_DATA
		if vehicle.usable_infr.subtype.is_empty():
			continue # A domain-only definition accepts all its subtypes.
		var found: bool = false
		for infrastructure: InfrType in self.infr_types:
			if infrastructure.key == vehicle.usable_infr.subtype:
				found = true
				break
		if not found:
			push_error("Vehicle %s references unknown infrastructure %s" % [vehicle.key, vehicle.usable_infr.subtype])
			return ERR_INVALID_DATA
	return OK

# == GETTER METHODS ==
#region Infrastructure
func get_road_type(key: String) -> RoadType:
	return self.road_types.get(key, self.road_types.get(InfrTypesLoader.DEFAULT_ROAD_TYPE))

## Unknown or legacy gauge keys fall back to standard gauge.
func get_rail_type(key: String) -> RailType:
	return self.rail_types.get(InfrType.normalize_rail_gauge(key), self.rail_types.get(InfrTypesLoader.DEFAULT_RAIL_TYPE))

func get_infr_type(key: String) -> InfrType:
	for infr_type: InfrType in self.infr_types:
		if infr_type.key == key: return infr_type
	Loggie.error("InfrType \"%s\" could not be found" % key)
	return null
#endregion

#region Residential Buildings
func get_rnd_placable_res_bld() -> ResBldType:
	for i in range(5):
		var rnd_res_type: ResBldType = self.res_bld_type_store.get_random()
		if rnd_res_type.block_auto_placement == false:
			return rnd_res_type
	return null

func get_res_bld_type(_key: String) -> ResBldType:
	return self.res_bld_type_store.get_by_key(_key)
#endregion

#region Industry Types
func get_ind_type(key: String) -> IndustryType:
	for found_type: IndustryType in self.industry_types:
		if found_type.key == key: return found_type
	Loggie.error("IndustryType \"%s\" could not be found" % key)
	return null
#endregion

#region Vehicle Types

func get_veh_type(veh_type_key: String) -> VehicleTypeData:
	if self.vehicle_types_dict.has(veh_type_key):
		return self.vehicle_types_dict.get(veh_type_key)
	if veh_type_key == "fkbn_t1_motorwagon" and self.vehicle_types_dict.has("fkb_t2_137_532"):
		return self.vehicle_types_dict["fkb_t2_137_532"]
	Loggie.warn("Cannot find VehicleType \"%s\"" % veh_type_key)
	return null
#endregion
