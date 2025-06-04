## This one will be instanciated out of a scene
@icon("res://assets/icons/icon_rail_track.png")
class_name OuterRailTrack extends VisibleObject

func set_track(_track: RailTrack):
	self.entity = _track
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

## used for fining center point for distance calculations
func get_middle_pos() -> Vector3:
	var road_vertice_count: int = self.entity.vertices.size()
	var middle_index: int = floori(road_vertice_count /2)
	return self.entity.vertices.get(middle_index)
