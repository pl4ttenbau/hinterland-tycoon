@icon("uid://dxyodhnxhip0d")
class_name VehicleData extends GameEntityData

@export var veh_type: VehicleTypeData

# optional: only rail vehicles have a train (yet)
@export var train: TrainData

static var _last_num: int = 0

#region Initialization
func _init():
	super(Enums.EntityTypes.VEHICLE)
	self._assign_new_num()
	
func _assign_new_num():
	VehicleData._last_num += 1
	self.num = VehicleData._last_num

static func of(_veh_type_key: String) -> VehicleData:
	# get vehicle type
	var veh_type_obj := VehicleTypeData.get_by_key(_veh_type_key)
	# instanciate correct scene
	var inst: VehicleData = VehicleData.new()
	inst.veh_type = veh_type_obj
	return inst
#endregion
