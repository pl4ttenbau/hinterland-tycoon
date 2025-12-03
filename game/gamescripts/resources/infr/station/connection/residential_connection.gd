class_name StationResidentialConnection extends Resource

@export var station: AbstractStation
@export_storage var house: Residence3D

func _init(_station: AbstractStation, _house: Residence3D):
	self.station = _station
	self.house = _house
