## This one will be instanciated out of a scene
@icon("res://assets/icons/nodes_3d/icon_rail_track.svg")
class_name RailTrack3D extends InfrLine3D

var is_construction_preview := false

@export var track: RailTrackData:
	set(value):
		self.bind_line(value)
		self._hide_bed_when_required(value)
	get():
		return self.entity as RailTrackData
		
#region Initialization
## Builds the view from the track's rail type scene; null when the type catalog cannot load.
static func of(track_data: RailTrackData) -> RailTrack3D:
	var definition: RailType = track_data.get_rail_type()
	if definition == null:
		return null
	track_data.ensure_curve()
	var view := definition.scene.instantiate() as RailTrack3D
	view.track = track_data
	return view

func _enter_tree() -> void:
	var bedding: PathMesh3D = get_bed_mesh()
	for child: Node in get_children():
		if child is PathMesh3D:
			# Only the bedding supports walking. Rails and sleepers stay visual
			# so their individual edges cannot obstruct the player's collider.
			var solid_bedding: bool = child == bedding and child.visible and not is_construction_preview
			child.collision_mode = PathMesh3D.COLLISION_MODE_TRIMESH if solid_bedding else PathMesh3D.COLLISION_MODE_NONE

func _name_prefix() -> String:
	return "RailTrack"

func _assign_mesh_names(prefix: String, num: int) -> void:
	# Find the bedding before renaming; it is identified by "Bed" in its name.
	get_bed_mesh().name = "%s_%d_BeddingMesh" % [prefix, num]
	get_child(1).name = "%s_%d_TracksMesh" % [prefix, num]
	
func _hide_bed_when_required(track_obj: RailTrackData):
	var bedding: PathMesh3D = self.get_bed_mesh()
	if bedding:
		bedding.visible = not track_obj.hideFill
		var solid_bedding: bool = bedding.visible and not is_construction_preview
		bedding.collision_mode = PathMesh3D.COLLISION_MODE_TRIMESH if solid_bedding else PathMesh3D.COLLISION_MODE_NONE
#endregion
	
func get_bed_mesh() -> PathMesh3D:
	for child in self.get_children():
		if child is PathMesh3D && child.name.contains("Bed"):
			return child as PathMesh3D
	Loggie.warn("Cannot find Bedding mesh in track \"%s\"" % self.name)
	return null
