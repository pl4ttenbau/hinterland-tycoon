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

func get_mesh() -> MeshInstance3D:
	return self.get_child(0)
