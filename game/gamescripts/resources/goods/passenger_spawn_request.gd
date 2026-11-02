## One resolved trip, before any inventory is changed. Stop identity is physical,
## even when several stops share an interchange name. No passenger Node is needed.
class_name PassengerSpawnRequest extends RefCounted

var origin_residence_num: int
var destination_residence_num: int
var origin_stop: AbstractStation
var destination_stop: AbstractStation

func _init(origin: ResidenceBuildingData, destination: ResidenceBuildingData,
		from_stop: AbstractStation, to_stop: AbstractStation) -> void:
	origin_residence_num = origin.num
	destination_residence_num = destination.num
	origin_stop = from_stop
	destination_stop = to_stop
