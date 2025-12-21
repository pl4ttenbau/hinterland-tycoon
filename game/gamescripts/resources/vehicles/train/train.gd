class_name TrainData extends GameObject

@warning_ignore("unused_signal")
signal locomotive_changed(loco: RailVehicleData)

@warning_ignore("unused_signal")
signal vehicles_changed(veh_arr: Array[RailVehicleData])

@export_storage var vehicles: Array[RailVehicleData] = []

@export_storage var locomotive: RailVehicleData:
	get(): return locomotive
	set(value): self._set_locomotive(value)

@export_storage var curr_path: VehiclePath

#region Initialization
func _init():
	super(Enums.EntityTypes.TRAIN)

static func of(_locomotive: RailVehicleData) -> TrainData:
	var inst = TrainData.new()
	inst.locomotive = _locomotive
	return inst
#endregion

#region Vehicle Changing
func _set_locomotive(_loco: RailVehicleData):
	self.locomotive = _loco
	self.locomotive_changed.emit(_loco)
	# add to vehicle list
	self.append_vehicle(_loco)
#endregion

func append_vehicle(_vehicle: RailVehicleData) -> Array[RailVehicleData]:
	self.vehicles.append(_vehicle)
	self.vehicles_changed.emit(self.vehicles)
	return self.vehicles
#endregion
