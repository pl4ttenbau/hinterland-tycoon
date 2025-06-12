class_name OuterRailStation extends HideableObject

const scene_source_path = "res://scenes/subscenes/infr/outer_rail_station.tscn"

static func of(_station_obj: RailStationResource) -> OuterRailStation:
	var prefab: PackedScene = preload(scene_source_path)
	var instanciated_container: OuterRailStation = prefab.instantiate()
	instanciated_container.position = _station_obj.position
	instanciated_container.entity = _station_obj
	instanciated_container.set_meta("station", _station_obj)
	# instanciated_container._name_nodes()
	return instanciated_container
	
func _name_nodes():
	self.name = "OuterRailStation_%d" % self.entity.num
	self.get_mesh().name = "RailStation_%d_Mesh" % self.entity.num
	
func rotate_to_prev_node():
	var station_node_index: int = self.entity.parent_node.index
	var prev_node = self.get_parent_track_node_by_index(station_node_index -1)
	self.look_at(prev_node.position)
	
func get_parent_track_node_by_index(_i: int) -> RailNode:
	var track: RailTrack = self.entity.parent_node.parent_track
	return track.get_rail_node(_i)

func get_mesh() -> MeshInstance3D:
	return self.get_child(0)
	
func get_collider() -> StaticBody3D:
	return self.get_child(1)
