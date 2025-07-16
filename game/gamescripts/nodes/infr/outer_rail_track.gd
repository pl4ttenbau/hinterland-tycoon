## This one will be instanciated out of a scene
@icon("res://assets/icons/icon_rail_track.png")
class_name OuterRailTrack extends VisibleObject

const SCENE_PATH = "res://assets/meshes/infr/rail/rail_track_normal/path_rail_normal_bedded.tscn"

@export var track: RailTrackData:
	set(value):
		self.entity = value
		$TrackPath.curve = value.curve
		self.assign_node_names()

func assign_node_names():
	self.name = "RailTrack_%d_Container" % self.entity.num
	$TrackPath.name = "RailTrack_%d_Path" % self.entity.num
	$BedPathMesh.name = "RailTrack_%d_BeddingMesh" % self.entity.num
	$TrackPathMesh.name = "RailTrack_%d_TracksMesh" % self.entity.num

## used for finding center point for distance calculations
func get_middle_pos() -> Vector3:
	var road_vertice_count: int = self.entity.vertices.size()
	var middle_index: int = floori(road_vertice_count /2)
	return self.entity.vertices.get(middle_index)
