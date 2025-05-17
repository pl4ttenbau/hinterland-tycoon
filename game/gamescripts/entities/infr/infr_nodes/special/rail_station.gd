class_name RailStation extends Node

@export var parent_node: RailNode
@export var station_name: String
@export var station_type: String
@export var town_name: String
@export var outer_node: Node3D
@export var position: Vector3

static func of_node_dict(_special_node_dict: Dictionary, _node: RailNode):
	var _station_name: String = _special_node_dict.get("stationName")
	var _station_town_name: String = _special_node_dict.get("stationTown")
	var _station_pos: Vector3 = _node.position
	var _instance: RailStation = RailStation.of(_node, _station_name, 
		_station_pos, _station_town_name)
	return _instance
	
static func of(_rail_node: RailNode, _name: String, _pos: Vector3, _town_name: String) -> RailStation:
	var instance: RailStation = RailStation.new()
	instance.station_name = _name
	instance.position = _pos
	instance.parent_node = _rail_node
	instance.town_name = _town_name
	instance.set_full_station_name()
	return instance
	
func spawn() -> OuterRailStation:
	self.outer_node = OuterRailStation.of(self)
	return self.outer_node
	
func set_full_station_name():
	self.station_name = self.town_name + "-" + self.station_name
	self.name = "Station_" + self.station_name
		
func get_track() -> RailTrack:
	return self.parent_node.parent_track
