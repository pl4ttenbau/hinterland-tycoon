## Rail definitions have their own catalog; road definitions can share VehicleTypeData.
class_name RailVehicleTypeData extends VehicleTypeData

const SCENE_PATH_FORMAT = "res://assets/meshes/vehicles/rail/%s/vehicle_%s.tscn"
const PREVIEW_PATH_FORMAT = "res://assets/meshes/vehicles/rail/%s/preview.png"
const PRICING = preload("res://game/jsondata/rail_vehicle_pricing.tres")

func get_purchase_price() -> Variant:
	return PRICING.price_for(self)

func get_mesh_path() -> String:
	return SCENE_PATH_FORMAT % [self.key, self.key]

func get_preview_img_path() -> String:
	return PREVIEW_PATH_FORMAT % self.key
