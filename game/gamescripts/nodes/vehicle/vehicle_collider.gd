class_name VehicleCollider extends ClickableCollider

@onready var vehicle: RailVehicle = self.get_parent_node_3d() as RailVehicle

func get_click_ref() -> ClickRef:
	var num: int = self.vehicle.vehicle_num
	return ClickRef.new(Enums.EntityTypes.VEHICLE, num)
