@icon("uid://dxyodhnxhip0d")
class_name RailVehicleType extends Resource

const SCENE_PATH_FORMAT = "res://assets/meshes/vehicles/rail/%s/vehicle_%s.tscn"
const PREVIEW_PATH_FORMAT = "res://assets/meshes/vehicles/rail/%s/preview.png"

@export var key: String

@export var display_name: String

@export var scene_path: String

@export var max_speed_kmh: int

@export var usable_infr: UsableInfrType

@export var has_motor: bool = false

@export var capacity: GoodsCapacity

#region Initialization
static func of_key(_key: String) -> RailVehicleType:
	var inst: RailVehicleType = RailVehicleType.new()
	inst.key = _key
	return inst
	
static func of_dict(_dict: Dictionary) -> RailVehicleType:
	return VehicleMapper.type_dict_to_class(_dict)
#endregion

#region Getters
func get_mesh_path() -> String:
	return SCENE_PATH_FORMAT % [self.key, self.key]
	
func get_preview_img_path() -> String:
	return PREVIEW_PATH_FORMAT % self.key
	
func is_locomotive(): return self.has_motor

static func get_by_key(veh_type_key: String) -> RailVehicleType:
	return GameTypes.get_veh_type(veh_type_key)
#endregion
