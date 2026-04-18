## This one will be instanciated out of a scene
@icon("res://assets/icons/icon_rail_track.png")
class_name RailTrack3D extends GameEntity3D

const SCENE_PATH_NORMAL = "res://assets/meshes/infr/rail/rail_track_normal/path_rail_normal_bedded.tscn"
const SCENE_PATH_750MM = "res://assets/meshes/infr/rail/rail_track_750mm/path_rail_750mm_bedded.tscn"
const SCENE_PATH_600MM = "res://assets/meshes/infr/rail/rail_track_600mm/path_rail_600mm_bedded.tscn"

signal track_assigned(track: RailTrackData)

@export var curve: Curve3D:
	get(): return $TrackPath.curve
	set(value): $TrackPath.curve = value

@export var track: RailTrackData:
	set(value):
		self.entity = value
		self.curve = value.curve
		self._hide_bed_when_required(track)
		self.track_assigned.emit(track)
	get():
		return self.entity as RailTrackData
		
#region Initialization
func _enter_tree() -> void:
	self.track_assigned.connect(Callable(self, "_on_track_set"))
	
func assign_node_names():
	self.name = "RailTrack_%d_Container" % self.entity.num
	$TrackPath.name = "RailTrack_%d_Path" % self.entity.num
	$BedPathMesh.name = "RailTrack_%d_BeddingMesh" % self.entity.num
	$TrackPathMesh.name = "RailTrack_%d_TracksMesh" % self.entity.num
	
func _hide_bed_when_required(track_obj: RailTrackData):
	if track_obj.hideFill == true:
		var bedding: PathMesh3D = self.get_bed_mesh()
		if bedding: bedding.visible = false
#endregion
		
static func get_scene_path(track_obj: RailTrackData) -> String:
	if track_obj.infr_type_key == "750_MM":
		return SCENE_PATH_750MM
	elif track_obj.infr_type_key == "600_MM":
		return SCENE_PATH_600MM
	else: return SCENE_PATH_NORMAL
	
func get_bed_mesh() -> PathMesh3D:
	for child in self.get_children():
		if child is PathMesh3D && child.name.contains("Bed"):
			return child as PathMesh3D
	Loggie.warn("Cannot find Bedding mesh in track \"%s\"" % self.name)
	return null
		
#region Callbacks
func _on_track_set(_track: RailTrackData):
	self.assign_node_names()
#endregion
