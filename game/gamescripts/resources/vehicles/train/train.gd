class_name TrainData extends GameEntityData

@warning_ignore("unused_signal")
signal locomotive_changed(loco: VehicleData)

@warning_ignore("unused_signal")
signal vehicles_changed(veh_arr: Array[VehicleData])

@export_storage var vehicles: Array[VehicleData] = []

var _locomotive: VehicleData

@export_storage var locomotive: VehicleData:
	get(): return _locomotive
	set(value):
		_locomotive = value
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

func replace_consist(ordered: Array[VehicleData], engine: VehicleData) -> void:
	var engine_changed: bool = _locomotive != engine
	vehicles = ordered
	_locomotive = engine
	if engine_changed:
		locomotive_changed.emit(engine)
	vehicles_changed.emit(vehicles)
#endregion
