## Rail definitions have their own catalog; road definitions can share VehicleTypeData.
class_name RailVehicleTypeData extends VehicleTypeData

const SCENE_PATH_FORMAT = "res://assets/meshes/vehicles/rail/%s/vehicle_%s.tscn"
const PREVIEW_PATH_FORMAT = "res://assets/meshes/vehicles/rail/%s/preview.png"

func get_mesh_path() -> String:
	return SCENE_PATH_FORMAT % [self.key, self.key]

func get_preview_img_path() -> String:
	return PREVIEW_PATH_FORMAT % self.key
