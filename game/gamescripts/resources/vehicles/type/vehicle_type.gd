@icon("uid://dxyodhnxhip0d")
class_name VehicleTypeData extends Resource

@export var key: String

@export var display_name: String

@export var model_scene_path: String

## Road models may be catalogued before their operating specifications are known.
## Loaded rail definitions still require a positive integer speed.
var max_speed_kmh: Variant = null

@export var usable_infr: UsableInfrType

@export var has_motor: bool = false

@export var capacity: GoodsCapacity

@export var length_metres: float

## Empty vehicle mass in metric tonnes and motor output in kilowatts. Variant preserves unknown (null) values;
## typed floats would turn unknown values into zero.
var mass_tonnes: Variant = null
var motor_power_kw: Variant = null
## Starting tractive effort in kN; null means it has not been supplied in the catalog.
var tractive_effort_kn: Variant = null

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

## Concrete vehicle domains supply their purchase-price balance.
func get_purchase_price() -> Variant:
	return null

static func get_by_key(veh_type_key: String) -> VehicleTypeData:
	return GameTypes.get_veh_type(veh_type_key)
#endregion
