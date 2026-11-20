## This one will be instanciated out of a scene
@icon("res://assets/icons/nodes_3d/icon_rail_track.svg")
class_name RailTrack3D extends GameEntity3D

signal track_assigned(track: RailTrackData)

var is_construction_preview := false

@export var curve: Curve3D:
	get(): return (get_child(0) as Path3D).curve
	set(value): (get_child(0) as Path3D).curve = value

@export var track: RailTrackData:
	set(value):
		var previous: RailTrackData = self.track
		if previous != null:
			previous.curve_built.disconnect(_on_curve_built)
		self.entity = value
		self.curve = value.curve
		value.curve_built.connect(_on_curve_built)
		self._hide_bed_when_required(track)
		self.track_assigned.emit(track)
	get():
		return self.entity as RailTrackData
		
#region Initialization
func _enter_tree() -> void:
	if not track_assigned.is_connected(_on_track_set):
		track_assigned.connect(_on_track_set)
	var bedding: PathMesh3D = get_bed_mesh()
	for child: Node in get_children():
		if child is PathMesh3D:
			# Only the bedding supports walking. Rails and sleepers stay visual
			# so their individual edges cannot obstruct the player's collider.
			var solid_bedding: bool = child == bedding and child.visible and not is_construction_preview
			child.collision_mode = PathMesh3D.COLLISION_MODE_TRIMESH if solid_bedding else PathMesh3D.COLLISION_MODE_NONE
	
func assign_node_names():
	self.name = "RailTrack_%d_Container" % self.entity.num
	get_child(0).name = "RailTrack_%d_Path" % self.entity.num
	get_bed_mesh().name = "RailTrack_%d_BeddingMesh" % self.entity.num
	get_child(1).name = "RailTrack_%d_TracksMesh" % self.entity.num
	
func _hide_bed_when_required(track_obj: RailTrackData):
	var bedding: PathMesh3D = self.get_bed_mesh()
	if bedding:
		bedding.visible = not track_obj.hideFill
		var solid_bedding: bool = bedding.visible and not is_construction_preview
		bedding.collision_mode = PathMesh3D.COLLISION_MODE_TRIMESH if solid_bedding else PathMesh3D.COLLISION_MODE_NONE
#endregion
		
## Builds the view from the track's rail type scene; null when the type catalog cannot load.
static func of(track_data: RailTrackData) -> RailTrack3D:
	var definition: RailType = track_data.get_rail_type()
	if definition == null:
		return null
	track_data.ensure_curve()
	var view := definition.scene.instantiate() as RailTrack3D
	view.track = track_data
	return view
	
func get_bed_mesh() -> PathMesh3D:
	for child in self.get_children():
		if child is PathMesh3D && child.name.contains("Bed"):
			return child as PathMesh3D
	Loggie.warn("Cannot find Bedding mesh in track \"%s\"" % self.name)
	return null
		
#region Callbacks
func _on_curve_built(built_curve: Curve3D) -> void:
	self.curve = built_curve

func _on_track_set(_track: RailTrackData):
	self.assign_node_names()
#endregion
