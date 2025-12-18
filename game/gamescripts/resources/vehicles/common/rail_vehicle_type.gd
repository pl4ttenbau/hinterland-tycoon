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

func _init(_key: String) -> void:
	self.key = _key
	self.register()
	
func register():
	pass
	
static func of_dict(_dict: Dictionary) -> RailVehicleType:
	var inst := RailVehicleType.new(_dict.get("key"))
	inst.display_name = _dict.get("name")
	inst.scene_path = _dict.get("scene_path")
	inst.max_speed_kmh = _dict.get("max_speed_kmh")
	if _dict.has("has_motor") && _dict.get("has_motor") == true:
		inst.has_motor = true
	# usable infr
	if _dict.has("usable_infr"):
		inst.usable_infr = UsableInfrType.of_dict(_dict.get("usable_infr"))
	# goods capacity
	if _dict.has("capacity"):
		inst.capacity = GoodsCapacity.of_json(_dict.get("capacity"))
	return inst

#region Getters
func get_mesh_path() -> String:
	return SCENE_PATH_FORMAT % [self.key, self.key]
	
func get_preview_img_path() -> String:
	return PREVIEW_PATH_FORMAT % self.key
	
func is_locomotive(): return self.has_motor

static func get_by_key(veh_type_key: String) -> RailVehicleType:
	for veh_type_obj: RailVehicleType in GameTypes.vehicle_types:
		if veh_type_obj.key == veh_type_key:
			return veh_type_obj
	Loggie.error("Cannot load vehicle type \"%s\"" % veh_type_key)
	return null
#endregion
