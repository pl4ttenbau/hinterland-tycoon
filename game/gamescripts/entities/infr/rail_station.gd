class_name RailStation extends Node

@export var parent_node: RailNode
@export var station_name: String
@export var station_type: String
@export var town_name: String
@export var outer_node: Node3D
@export var position: Vector3

func _init() -> void:
	self.set_full_station_name()

static func of_node_dict(_special_node_dict: Dictionary, _node: RailNode):
	var station_name: String = _special_node_dict.get("stationName")
	var station_town: String = _special_node_dict.get("stationTown")
	var station_pos: Vector3 = _node.position
	var instance: RailStation = RailStation.of(_node, station_name, 
		station_pos, station_town)
	return instance
	
static func of(_rail_node: RailNode, _name: String, _pos: Vector3, _town_name: String) -> RailStation:
	var instance: RailStation = RailStation.new()
	instance.station_name = _name
	instance.position = _pos
	instance.parent_node = _rail_node
	instance.town_name = _town_name
	return instance
	
func spawn() -> OuterRailStation:
	self.outer_node = OuterRailStation.of(self)
	return self.outer_node
	
func set_full_station_name():
	self.station_name = self.town_name + "-" + self.station_name
	self.name = "Station_" + self.station_name
		
func get_track() -> RailTrack:
	return self.parent_node.parent_track
