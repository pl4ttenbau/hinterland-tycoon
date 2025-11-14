@icon("res://assets/icons/icon_station_white.png")
class_name RailStationData extends AbstractStation

## connections
@export var connected_town: TownData

## rail nodes
@export var position: Vector3

@export var node_stations: Array[RailNodeStationData] = []

#region Initialization
func _init(_num: int, _name: String, _town_num: int):
	super()
	self.num = _num
	self.station_name = _name
	self.town_num = _town_num
	
static func of_dict(_station_data: Dictionary) -> RailStationData:
	var station_obj := RailStationData.new(
		_station_data.get("num"),
		_station_data.get("name"),
		_station_data.get("townNum")
	)
	if _station_data.has("type"):
		station_obj.station_type = _station_data.get("type")
	if _station_data.has("hideBuilding"):
		station_obj.hide_building = true
	if _station_data.has("townName"):
		station_obj.town_name = _station_data.get("townName")
	return station_obj

func connect_node_station(node_station: RailNodeStationData):
	self.node_stations.append(node_station)
	node_station.parent_station = self
	# set position if none has been set yet (maybe change that later)
	if ! self.position: self.position = node_station.parent_node.position
#endregion

static func get_by_num(station_num: int) -> RailStationData:
	var found = Managers.stations.stations_by_num.get(station_num)
	if ! found: Loggie.error("Cannot find RailStation with num %d" % station_num)
	return found
