class_name RailVehicleData extends GameObject

@export var veh_type: VehicleTypeData

static var _last_num: int = 0

func _init():
	super(Enums.EntityTypes.VEHICLE)
	self._assign_new_num()
	
func _assign_new_num():
	RailVehicleData._last_num += 1
	self.num = RailVehicleData._last_num

static func of(_veh_type_key: String) -> RailVehicleData:
	# get vehicle type
	var veh_type_obj := VehicleTypeData.get_by_key(_veh_type_key)
	# instanciate correct scene
	var inst: RailVehicleData = RailVehicleData.new()
	inst.veh_type = veh_type_obj
	return inst
