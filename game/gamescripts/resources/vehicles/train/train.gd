class_name TrainData extends GameEntityData

@warning_ignore("unused_signal")
signal locomotive_changed(loco: VehicleData)

@warning_ignore("unused_signal")
signal vehicles_changed(veh_arr: Array[VehicleData])

@export_storage var vehicles: Array[VehicleData] = []

@export_storage var locomotive: VehicleData:
	get(): return locomotive
	set(value):
		## Store inside the setter; assigning this property from a helper calls the setter again.
		locomotive = value
		self.locomotive_changed.emit(value)
		self.append_vehicle(value)

#region Initialization
func _init():
	super(Enums.EntityTypes.TRAIN)

static func of(_locomotive: VehicleData) -> TrainData:
	var inst = TrainData.new()
	inst.locomotive = _locomotive
	return inst
#endregion

#region Vehicle Changing
func append_vehicle(_vehicle: VehicleData) -> Array[VehicleData]:
	self.vehicles.append(_vehicle)
	self.vehicles_changed.emit(self.vehicles)
	return self.vehicles
#endregion
