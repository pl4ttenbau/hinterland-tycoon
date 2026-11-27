class_name StationResidentialConnection extends Resource

## Station and interchange are held weakly: they own this entry through their
## StationConnections, so strong back-references would form cycles and leak.
var station: AbstractStation:
	set(value): _station = weakref(value) if value != null else null
	get(): return _station.get_ref() if _station != null else null
var _station: WeakRef = null

var interchange: InterchangeData:
	set(value): _interchange = weakref(value) if value != null else null
	get(): return _interchange.get_ref() if _interchange != null else null
var _interchange: WeakRef = null

@export_storage var house: Residence3D

func _init(parent: GameEntityData = null, _house: Residence3D = null, reachable: Array[AbstractStation] = []):
	self.interchange = parent as InterchangeData
	self.station = reachable[0] if not reachable.is_empty() else parent as AbstractStation
	self.house = _house
