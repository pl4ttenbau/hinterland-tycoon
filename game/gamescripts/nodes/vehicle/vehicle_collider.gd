class_name VehicleCollider extends ClickableCollider

@export var vehicle: RailVehicle3D:
	get(): 
		return self.get_parent_node_3d() as RailVehicle3D

func get_click_ref() -> ClickRef:
	var num: int = self.vehicle.vehicle_num
	return ClickRef.new(Enums.EntityTypes.VEHICLE, num)
