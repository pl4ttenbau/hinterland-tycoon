## This one will be instanciated out of a scene
@icon("res://assets/icons/icon_rail_track.png")
class_name OuterRailTrack extends VisibleObject

@export var track: RailTrackData:
	set(value):
		self.entity = value
		self.get_path_3d().curve = value.curve
		self.assign_node_names()

const SCENE_PATH = "res://scenes/subscenes/infr/rail_path_mesh_3d.tscn"

func assign_node_names():
	var track_num: int = self.entity.num
	self.name = "RailTrack_%d_Container" % track_num
	self.get_path_3d().name = "RailTrack_%d_Path" % track_num
	self.get_rail_mesh().name = "RailTrack_%d_Mesh" % track_num

func get_path_3d() -> Path3D:
	return self.get_child(0) as Path3D
	
func get_rail_mesh() -> PathMesh3D:
	return self.get_child(1)

## used for fining center point for distance calculations
func get_middle_pos() -> Vector3:
	var road_vertice_count: int = self.entity.vertices.size()
	var middle_index: int = floori(road_vertice_count /2)
	return self.entity.vertices.get(middle_index)
