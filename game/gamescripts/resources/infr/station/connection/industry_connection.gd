class_name StationIndustryConnection extends Resource

@export var station: AbstractStation
@export var interchange: InterchangeData
@export var reachable_stops: Array[AbstractStation] = []
@export var industry: IndustryData

func _init(parent: GameEntityData = null, _industry: IndustryData = null, reachable: Array[AbstractStation] = []):
	self.interchange = parent as InterchangeData
	self.reachable_stops.assign(reachable)
	self.station = reachable[0] if not reachable.is_empty() else parent as AbstractStation
	self.industry = _industry
