class_name VehicleCollider extends ClickableCollider

@export var vehicle3d: Vehicle3D:
	get(): 
		var par_node: Node3D = self.get_parent_node_3d()
		if !par_node is Vehicle3D:
			Loggie.error("parent of \"\" is not Vehicle3D" % self.get_path())
			return null
		else:
			return self.get_parent_node_3d() as Vehicle3D

func get_click_ref() -> ClickRef:
	var num: int = self.vehicle3d.vehicle_obj.num
	return ClickRef.new(Enums.EntityTypes.VEHICLE, num)
