class_name RailStationData extends GameObject

@export var parent_node: RailNodeData
@export var station_name: String
@export var station_type: String
@export var position: Vector3
@export var town_name: String
@export_storage var outer_node: OuterRailStation

static var _last_station_num: int = 0

func _init():
	super(Enums.EntityTypes.STATION)

static func of_node_dict(_special_node_dict: Dictionary, _node: RailNodeData) -> RailStationData:
	var _station_name: String = _special_node_dict.get("stationName")
	var _station_town_name: String = _special_node_dict.get("stationTown")
	var _station_pos: Vector3 = _node.position
	var _instance := RailStationData.of(_node, _station_name, _station_town_name)
	return _instance
	
static func of_station_dict(_station_dict: Dictionary, _node: RailNodeData) -> RailStationData:
	var _name: String = _station_dict.get("name")
	var _town_name: String = _station_dict.get("townName")
	var _pos: Vector3 = _node.position
	return RailStationData.of(_node, _name, _town_name)
	
static func of(_rail_node: RailNodeData, _name: String, _town_name: String) -> RailStationData:
	var instance := RailStationData.new()
	instance.station_name = _name
	instance.position = _rail_node.position
	instance.parent_node = _rail_node
	instance.town_name = _town_name
	instance.set_full_station_name()
	return instance
	
func spawn() -> OuterRailStation:
	self.outer_node = OuterRailStation.of(self)
	return self.outer_node
	
func set_full_station_name():
	self.station_name = self.town_name + "-" + self.station_name
	#self.name = "Station_" + self.station_name
		
func get_track() -> RailTrackData:
	return self.parent_node.parent_track
	
static func next_station_num() -> int:
	RailStationData._last_station_num += 1
	return RailStationData._last_station_num
