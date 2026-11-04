@icon("res://assets/icons/icon_station_white.png")
class_name RailStationData extends AbstractStation

## connections
@export var connected_town: TownData

## rail nodes
@export var position: Vector3:
	get(): return position
	set(value):
		position = value
		self.positioned.emit(value)

@export var node_stations: Array[NodeStationLinkData] = []
@export var track_num: int = -1
@export var node_index: int = -1

#region Initialization
func _init(_num: int = -1, _name: String = "", _town_num: int = -1):
	super()
	self.num = _num
	self.station_name = _name
	self.town_num = _town_num
	
static func of_dict(_station_data: Dictionary) -> RailStationData:
	for field: String in ["num", "trackNum", "nodeIndex"]:
		if not InterchangeData.is_valid_num(_station_data.get(field)):
			push_error("Rail stop requires a nonnegative integer %s" % field)
			return null
	if not _station_data.get("type", "STATION_PASS") is String \
			or not _station_data.get("hideBuilding", false) is bool:
		push_error("Rail stop type/hideBuilding metadata is invalid")
		return null
	# Name and town are inherited from the interchange after registration.
	var station_obj := RailStationData.new(int(_station_data["num"]))
	station_obj.track_num = int(_station_data["trackNum"])
	station_obj.node_index = int(_station_data["nodeIndex"])
	station_obj.station_type = _station_data.get("type", "STATION_PASS")
	station_obj.hide_building = _station_data.get("hideBuilding", false)
	return station_obj

func connect_node_station(node_station: NodeStationLinkData):
	self.node_stations.append(node_station)
	node_station.parent_station = self
	# set position if none has been set yet (maybe change that later)
	if ! self.position: self.position = node_station.parent_node.position
#endregion

static func get_by_num(station_num: int) -> RailStationData:
	var found = Managers.stations.stations_by_num.get(station_num)
	if ! found: Loggie.error("Cannot find RailStation with num %d" % station_num)
	return found
