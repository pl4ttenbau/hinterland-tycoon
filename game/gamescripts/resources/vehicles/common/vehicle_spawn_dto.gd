class_name VehicleSpawnDto extends RefCounted

var vehicle_type_key: String
var depot_num: int

func _init(_vehicle_type_key: String, _depot_num: int):
	self.vehicle_type_key = _vehicle_type_key
	self.depot_num = _depot_num
