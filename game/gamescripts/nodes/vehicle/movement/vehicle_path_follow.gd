class_name VehiclePathFollow extends PathFollow3D

static func of_train_vehicle(vehicle_index: int, vehicle3d: Vehicle3D) -> VehiclePathFollow:
	var inst := VehiclePathFollow.new()
	inst.loop = false
	inst.use_model_front = true
	inst.name = "PathFollow_Vehicle_%d" % vehicle_index
	inst.rotation_mode = PathFollow3D.ROTATION_Y
	inst.add_child(vehicle3d)
	return inst
