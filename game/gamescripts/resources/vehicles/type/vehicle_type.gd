@icon("uid://dxyodhnxhip0d")
class_name VehicleTypeData extends Resource

@export var key: String

@export var display_name: String

@export var model_scene_path: String

@export var max_speed_kmh: int

@export var usable_infr: UsableInfrType

@export var has_motor: bool = false

@export var capacity: GoodsCapacity

@export var length_metres: float

## Empty vehicle mass in metric tonnes and motor output in kilowatts. Variant preserves unknown (null) values;
## typed floats would turn unknown values into zero.
var mass_tonnes: Variant = null
var motor_power_kw: Variant = null

#region Initialization
static func of_key(_key: String) -> VehicleTypeData:
	var inst: VehicleTypeData = VehicleTypeData.new()
	inst.key = _key
	return inst
	
static func of_dict(_dict: Dictionary) -> VehicleTypeData:
	return VehicleMapper.type_dict_to_class(_dict)
#endregion

#region Getters
func get_mesh_path() -> String:
	return self.model_scene_path
	
func get_preview_img_path() -> String:
	return self.model_scene_path.get_base_dir().path_join("preview.png")
	
func is_locomotive(): return self.has_motor

static func get_by_key(veh_type_key: String) -> VehicleTypeData:
	return GameTypes.get_veh_type(veh_type_key)
#endregion
