class_name RailStationData extends ResourceContainer

# json properties
@export var station_name: String
@export var station_type: String
@export var town_name: String
@export var town_num: int

# indirect properties
@export var position: Vector3
@export var parent_node: RailNodeData
@export_storage var outer_node: OuterRailStation
@export_storage var connected_town: TownData

static var _last_station_num: int = 0

func _init():
	super(Enums.EntityTypes.STATION)
	
static func of_station_dict(_station_dict: Dictionary, _node: RailNodeData) -> RailStationData:
	var _name: String = _station_dict.get("name")
	var _town_name: String = _station_dict.get("townName")
	var _town_num: int = _station_dict.get("townNum")
	var _pos: Vector3 = _node.position
	return RailStationData.of(_node, _name, _town_num, _town_name)
	
static func of(_rail_node: RailNodeData, _name: String, _town_num: int, _town_name: String) -> RailStationData:
	var instance := RailStationData.new()
	instance.station_name = _name
	instance.position = _rail_node.position
	instance.parent_node = _rail_node
	instance.town_num = _town_num
	instance.town_name = _town_name
	instance._set_full_station_name()
	return instance
	
func spawn() -> OuterRailStation:
	self.outer_node = OuterRailStation.of(self)
	self._register_connected_town()
	return self.outer_node
	
func _set_full_station_name():
	self.station_name = self.town_name + "-" + self.station_name
	#self.name = "Station_" + self.station_name
	
## save local town and also add itself to town's station list
func _register_connected_town():
	for town in GlobalState.towns:
		if town.num == self.town_num:
			self.connected_town = town
			town.connect_new_station(self)

#region Helper Methods
static func next_station_num() -> int:
	RailStationData._last_station_num += 1
	return RailStationData._last_station_num
#endregion
