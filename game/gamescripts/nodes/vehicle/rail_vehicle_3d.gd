@icon("res://assets/icons/nodes_3d/icon_locomotive.svg")
class_name RailVehicle3D extends GameEntity3D

@export var vehicle_obj: VehicleData
@export var num_in_train: int
@export var train3d: Train3D
@export var offset_to_first: float
## A vehicle may face either way within the ordered consist.
@export var faces_rear: bool = false

#region Static Constructors
static func of_vehicle_obj(_veh_obj: VehicleData, _train3d: Train3D = null) -> RailVehicle3D:
	var mesh_scene_path = _veh_obj.veh_type.model_scene_path
	var veh3d: RailVehicle3D = load(mesh_scene_path).instantiate()
	# Some legacy models use Default/Deco. All spawned vehicle geometry belongs
	# on Vehicles so static reflection captures never retain a parked train.
	for visual: Node in veh3d.find_children("*", "GeometryInstance3D", true, false):
		(visual as GeometryInstance3D).layers = 64
	veh3d.vehicle_obj = _veh_obj
	if _train3d:
		veh3d.train3d = _train3d
	return veh3d

func calc_offset_to_first() -> float:
	var i_in_train: int = self.num_in_train
	var total_offset = 0.0
	while i_in_train > 0:
		total_offset += self.calc_offset_to_previous(i_in_train)
		i_in_train -= 1
	return total_offset

func calc_offset_to_previous(i_in_train: int)-> float:
	if i_in_train == 0: return 0.0
	var veh_before: RailVehicle3D = self.train3d.vehicles[i_in_train -1]
	## Use this pair's following vehicle, not the final wagon for every pair.
	var half_own_length: float = self.train3d.vehicles[i_in_train].vehicle_obj.veh_type.length_metres /2
	var half_other_length: float = veh_before.vehicle_obj.veh_type.length_metres /2
	return half_own_length + half_other_length
#endregion
