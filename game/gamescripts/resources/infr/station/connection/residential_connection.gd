class_name StationResidentialConnection extends Resource

@export var station: AbstractStation
@export_storage var house: OuterResBld

func _init(_station: AbstractStation, _house: OuterResBld):
	self.station = _station
	self.house = _house
