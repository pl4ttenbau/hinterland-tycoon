@icon("uid://u0j0akdffkcy")
class_name Vehicle3D extends VisibleObject

@export var vehicle_obj: VehicleData
@export var num_in_train: int
@export var train3d: Train3D
@export var offset_in_m: float

#region Initialization
func _enter_tree() -> void:
	self.train3d.on_vehicle_added.connect(Callable(self, "_on_vehicle_added_to_train"))
#endregion

#region Static Constructors
static func of_vehicle_obj(_veh_obj: VehicleData, _train3d: Train3D = null) -> Vehicle3D:
	var mesh_scene_path = _veh_obj.veh_type.model_scene_path
	var veh3d: Vehicle3D = load(mesh_scene_path).instantiate()
	veh3d.vehicle_obj = _veh_obj
	if _train3d:
		veh3d.train3d = _train3d
	return veh3d

func calc_offset_to_last() -> float:
	if self.num_in_train == 0: return 0.0
	else:
		var veh_before: Vehicle3D = self.train3d.vehicles[self.num_in_train -1]
		var half_own_length: float = self.vehicle_obj.veh_type.length_metres /2
		var half_other_length: float = veh_before.vehicle_obj.veh_type.length_metres /2
		return half_own_length + half_other_length
#endregion

#region Callbacks
func _on_vehicle_added_to_train(_new_veh3d: Vehicle3D):
	self.offset_in_m = self.calc_offset_to_last()
#endregion
