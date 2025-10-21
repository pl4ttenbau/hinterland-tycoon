class_name StationIndustryConnection extends Resource

@export var station: AbstractStation
@export var industry: IndustryData

func _init(_station: AbstractStation, _industry: IndustryData):
	self.station = _station
	self.industry = _industry
