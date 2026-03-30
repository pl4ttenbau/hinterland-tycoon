class_name TrainVehicleDto extends Resource

@export var index: int
@export var veh_type_key: String:
	get(): return veh_type_key
	set(value):
		veh_type_key = value
		veh_type_obj = GameTypes.get_veh_type(value)

@export_storage var veh_type_obj: VehicleTypeData

static func of(_index: int, _veh_type_key: String) -> TrainVehicleDto:
	var dto: TrainVehicleDto = TrainVehicleDto.new()
	dto.index = _index
	dto.veh_type_key = _veh_type_key
	return dto
