## A resolved trip from a physical boarding point to a destination interchange.
class_name PassengerSpawnRequest extends RefCounted

var origin_residence_num: int
var destination_residence_num: int
var origin_stop: AbstractStation
var destination_interchange: InterchangeData

func _init(origin: ResidenceBuildingData, destination: ResidenceBuildingData,
		from_stop: AbstractStation, destination_station: InterchangeData) -> void:
	origin_residence_num = origin.num
	destination_residence_num = destination.num
	origin_stop = from_stop
	destination_interchange = destination_station
