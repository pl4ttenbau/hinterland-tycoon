@icon("uid://u0j0akdffkcy")
class_name Vehicle3D extends VisibleObject

@export var vehicle_obj: VehicleData

@export var train3d: Train3D

@export var offset_in_m: int

#region Initialization

#endregion

#region Static Constructors
static func of_vehicle_obj(_veh_obj: VehicleData, _train3d: Train3D = null) -> Vehicle3D:
	var mesh_scene_path = _veh_obj.veh_type.model_scene_path
	var veh3d: Vehicle3D = load(mesh_scene_path).instantiate()
	veh3d.vehicle_obj = _veh_obj
	if _train3d:
		veh3d.train3d = _train3d
	return veh3d
#endregion
