class_name RailVehicleType extends Resource

const SCENE_PATH_FORMAT = "res://assets/meshes/vehicles/rail/%s/vehicle_%s.tscn"
const PREVIEW_PATH_FORMAT = "res://assets/meshes/vehicles/rail/%s/preview.png"

@export var key: String

@export var mesh_name: String

@export var max_speed_kmh: int

@export var track_type: String

@export var has_motor: bool

func _init(_key: String) -> void:
	self.key = _key
	self.register()
	
func register():
	pass

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
