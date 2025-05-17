class_name OuterRailStation extends Node3D

const scene_source_path = "res://scenes/subscenes/outer_rail_station.tscn"

@export_storage var station_object: RailStation

static func of(_station_obj: RailStation) -> OuterRailStation:
	var prefab: PackedScene = preload(scene_source_path)
	var instanciated_container: OuterRailStation = prefab.instantiate()
	instanciated_container.position = _station_obj.position
	instanciated_container.station_object = _station_obj
	instanciated_container.set_meta("station", _station_obj)
	return instanciated_container
	
func rotate_to_prev_node():
	var station_node_index: int = self.station_object.parent_node.index
	var prev_node = self.get_parent_track_node_by_index(station_node_index -1)
	self.look_at(prev_node.position)
	
func get_parent_track_node_by_index(_i: int) -> RailNode:
	var track: RailTrack = self.station_object.parent_node.parent_track
	return track.get_rail_node(_i)

func get_mesh() -> MeshInstance3D:
	return self.get_child(0)
