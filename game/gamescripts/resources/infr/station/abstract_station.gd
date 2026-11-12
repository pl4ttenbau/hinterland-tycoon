@abstract 
@icon("res://assets/icons/icon_station_white.png")
class_name AbstractStation extends GameEntityData

@warning_ignore("unused_signal")
signal positioned(pos_vec3: Vector3)

## Physical stops share their interchange's identity metadata. Legacy standalone
## objects retain their own fields, which keeps factories and editor tools usable.
@export var interchange: InterchangeData

var interchange_num: int:
	get(): return self.interchange.num if self.interchange != null else -1

@export var station_name: String:
	get(): return self.interchange.interchange_name if self.interchange != null else station_name

@export var town_num: int:
	get(): return self.interchange.town_num if self.interchange != null else town_num
	set(value):
		town_num = value
		# self.connect_to_town(value)

@export var station_type: String

## optional
@export var town_name: String:
	get(): return self.interchange.town_name if self.interchange != null else town_name

@export var hide_building: bool = false

## Runtime placement along the infrastructure curve. -1 retains authored node anchors.
@export var curve_offset: float = -1.0

@export var connections: StationConnections = StationConnections.new(self)

func _init():
	super(Enums.EntityTypes.STATION)

## Resolve the existing per-stop inventory without privileging either mode.
func get_inventory_view() -> InventoryEntity3D:
	if self is RailStationData and is_instance_valid(Managers.stations):
		return Managers.stations.get_station_3d_with_num(self.num)
	if self is RoadStationData and is_instance_valid(Managers.road_stops):
		return Managers.road_stops.containers_by_num.get(self.num)
	return null

## fetches TownData via given town num & saves reference in connected_town
func connect_to_town(_town_num):
	# set town name if not manually done
	if ! self.town_name:
		self.town_name = TownData.get_town_by_num(self.town_num).town_name
	# connect to town
	var _connected_town := TownData.get_town_by_num(_town_num)
	if _connected_town:
		self.connected_town = _connected_town
		_connected_town.connect_new_station(self)
