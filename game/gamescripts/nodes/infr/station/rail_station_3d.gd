@tool
class_name RailStation3D extends InventoryEntity3D

signal station_assigned(station_obj: RailStationData)

signal station_placed(vec3_pos: Vector3)

const STATION_NAME_FORMAT = "Station3D_%s-%s"

@export var station: RailStationData:
	set(value):
		self.entity = value
		self.station_assigned.emit(value)
	get():
		return self.entity as RailStationData

@export var station_pos: Vector3:
	get(): return station_pos
	set(value): 
		station_pos = value
		self.position = value
		self.station_placed.emit(value)

func get_shared_inventory() -> GoodsInventory:
	return station.get_interchange_inventory() if station != null else null

#region Initialization
# must be done in init, as station obj is assigned before scene tree entering
func _init() -> void:
	super()
	# connect to signals
	if not Engine.is_editor_hint():
		self.station_assigned.connect(Callable(self, "_on_station_assigned"))
#endregion

#region Callbacks
func _on_station_assigned(station_obj: RailStationData):
	station_obj.positioned.connect(Callable(self, "_on_station_positioned"))

func _on_station_positioned(pos: Vector3):
	self.station_pos = pos
#endregion

func _requires_constructable() -> bool:
	return true
