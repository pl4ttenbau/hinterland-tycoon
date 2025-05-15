class_name RailStation extends Node3D

@onready var stations: StationsHolder = $/root/World/Static/Infr/Stations

@export var parent_node: RailNode
@export var station_name: String
@export var station_type: String
@export var town_name: String
@export var instanciated: Node3D

func of_node_dict(rail_node_dict: Dictionary):
	pass
	
static func of(_rail_node: RailNode, _name: String, _pos: Vector3, _town_name: String) -> RailStation:
	var instance: RailStation = RailStation.new()
	instance.station_name = _name
	instance.position = _pos
	instance.parent_node = _rail_node
	instance.town_name = _town_name
	return instance
	
func spawn() -> Node3D:
	var prefab: PackedScene = preload("res://scenes/subscenes/rail_station_zone.tscn")
	var instanciated_container: Node3D = prefab.instantiate()
	instanciated_container.position = self.position
	self.instanciated = instanciated_container
	return instanciated_container
		
func get_track() -> RailTrack:
	return self.parent_node.parent_track
