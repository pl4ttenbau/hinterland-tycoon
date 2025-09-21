class_name VehicleTypesLoader extends AbstractGameTypeLoader

func _init() -> void:
	GameTypes.vehicle_types = make_types()

static func make_types() -> Array[RailVehicleType]:
	var vehicle_types: Array[RailVehicleType] = [
		new_vehicle("loco_faur", 45, "750_MM"),
		new_vehicle("wismar_railbus", 40, "NORMAL_GAUGE")
	]
	return vehicle_types
	
static func new_vehicle(key: String, max_speed: int, rail_type: String) -> RailVehicleType:
	var inst = RailVehicleType.new(key)
	inst.max_speed_kmh = max_speed
	inst.track_type = rail_type
	return inst
