## This one will be instanciated out of a scene
class_name OuterRailTrack extends Node3D

@export var rail_track: RailTrack

func set_track(_track: RailTrack):
	self.rail_track = _track
	self.get_path_3d().curve = _track.curve
	# rename name
	self.name = "RailTrack_%d_Container" % _track.num
	# set names of children
	self.get_path_3d().name = "RailTrack_Path_%d" % _track.num
	self.get_rail_mesh().name = "RailTrack_Mesh_%d" % _track.num

func get_path_3d() -> Path3D:
	return self.get_child(0) as Path3D
	
func get_rail_mesh() -> PathMesh3D:
	return self.get_child(1)
	
func get_middle_pos() -> Vector3:
	var road_vertice_count: int = self.rail_track.vertices.size()
	var middle_index: int = floor(road_vertice_count /2)
	return self.rail_track.vertices.get(middle_index)
