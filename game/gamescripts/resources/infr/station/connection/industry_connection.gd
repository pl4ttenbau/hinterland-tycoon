class_name StationIndustryConnection extends Resource

@export var station: RailStationData
@export var industry: IndustryData

func _init(_station: RailStationData, _industry: IndustryData):
	self.station = _station
	self.industry = _industry
