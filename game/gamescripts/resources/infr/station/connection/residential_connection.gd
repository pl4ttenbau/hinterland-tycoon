class_name StationResidentialConnection extends Resource

@export var station: AbstractStation
@export var interchange: InterchangeData
@export var reachable_stops: Array[AbstractStation] = []
@export_storage var house: Residence3D

func _init(parent: GameEntityData = null, _house: Residence3D = null, reachable: Array[AbstractStation] = []):
	self.interchange = parent as InterchangeData
	self.reachable_stops.assign(reachable)
	self.station = reachable[0] if not reachable.is_empty() else parent as AbstractStation
	self.house = _house
