@tool
@icon("uid://r84qkk5fcxhq")
class_name VehicleTypesLoader extends Node

@export var types_list: VehicleTypesList

const VEHICLE_TYPES_RES_PATH = "res://game/godotdata/vehicle_types/vehicle_types_list.tres"

#region Initialization
func _ready() -> void:
	GameTypes.set_and_sort_veh_types(self.types_list.list)
	Loggie.info("%s vehicle types loaded" % self.types_list.size())

## currently disabled
func load_vehicle_list() -> VehicleTypesList:
	var loaded = preload(VEHICLE_TYPES_RES_PATH)
	if loaded is VehicleTypesList:
		return loaded as VehicleTypesList
	Loggie.error("Cannot load VehiclesTypesList from %s" % VEHICLE_TYPES_RES_PATH)
	return null
#endregion
