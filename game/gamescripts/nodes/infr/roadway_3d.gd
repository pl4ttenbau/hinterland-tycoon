@icon("res://assets/icons/nodes_3d/icon_road.svg")
class_name RoadWay3D extends GameEntity3D

## Reference measurements of the source tile, before applying the road type.
@export var source_drivable_width_metres: float = 0.0
@export var source_mesh_height_metres: float = 0.0

@export var road: RoadData:
	set(value):
		self.entity = value
		# Road curves are in world coordinates, like rail tracks.
		self.position = Vector3.ZERO
		InfrUtils.fit_short_path_mesh(get_road_mesh(), value.curve)
		self.get_path_3d().curve = value.curve
		self.assign_node_names()
	get(): return self.entity as RoadData

#region Initialization
func _enter_tree() -> void:
	# Configure before the child's READY builds the warped mesh. The addon owns
	# the static body and rebuilds it whenever the path/mesh changes.
	get_road_mesh().collision_mode = PathMesh3D.COLLISION_MODE_TRIMESH

func assign_node_names():
	var track_num: int = self.entity.num
	self.name = "Road_%d_Container" % track_num
	self.get_path_3d().name = "Road_%d_Path" % track_num
	self.get_road_mesh().name = "Road_%d_Mesh" % track_num

func has_mesh_profile() -> bool:
	return source_drivable_width_metres > 0.0 and get_child_count() >= 2 \
		and get_child(0) is Path3D and get_child(1) is PathMesh3D and get_road_mesh().mesh != null

## The path modifier works in road-local cross sections, including on bends.
## The generated collision uses the same warped vertices as the visible road.
func apply_mesh_profile(definition: RoadType) -> void:
	var width_scale: float = definition.drivable_width_metres / source_drivable_width_metres
	var height_offset: float = definition.mesh_height_metres - source_mesh_height_metres
	if is_equal_approx(width_scale, 1.0) and is_zero_approx(height_offset):
		return
	var profile := PathModifier3D.new()
	profile.scale_modifier = Vector3(width_scale, 1.0, 1.0)
	profile.position_modifier = Vector3(0.0, height_offset, 0.0)
	get_road_mesh().add_child(profile)
#endregion

#region Getters
func get_path_3d() -> Path3D:
	return self.get_child(0)
	
func get_road_mesh() -> PathMesh3D:
	return self.get_child(1)
#endregion
