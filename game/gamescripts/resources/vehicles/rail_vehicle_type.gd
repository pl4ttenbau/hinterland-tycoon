class_name RailVehicleType extends Resource

const SCENE_PATH_FORMAT = "res://assets/meshes/vehicles/rail/%s/vehicle_%s.tscn"

@export var key: String

@export var mesh_name: String

@export var max_speed_kmh: int

@export var track_type: String

func _init(_key: String) -> void:
	self.key = _key
	self.register()
	
func register():
	pass

func get_mesh_path() -> String:
	return SCENE_PATH_FORMAT % [self.key, self.key]
	
