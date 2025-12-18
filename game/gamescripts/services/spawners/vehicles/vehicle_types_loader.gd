@tool
@icon("uid://r84qkk5fcxhq")
class_name VehicleTypesLoader extends Node

@export var types_list: VehicleTypesList

const VEHICLE_TYPES_RES_PATH = "res://game/godotdata/vehicle_types/vehicle_types_list.tres"

#region Initialization
func _ready() -> void:
	var veh_types: Array[VehicleTypeData] = self.types_list.list
	GameTypes.set_and_sort_veh_types(veh_types)
	Loggie.info("%d vehicle types loaded" % veh_types.size())

## currently disabled
func load_vehicle_list() -> VehicleTypesList:
	var loaded = preload(VEHICLE_TYPES_RES_PATH)
	if loaded is VehicleTypesList:
		return loaded as VehicleTypesList
	Loggie.error("Cannot load VehiclesTypesList from %s" % VEHICLE_TYPES_RES_PATH)
	return null
#endregion
