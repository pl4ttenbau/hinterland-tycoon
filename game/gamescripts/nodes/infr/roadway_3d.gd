@icon("res://assets/icons/nodes_3d/icon_road.svg")
class_name RoadWay3D extends InfrLine3D

## Reference measurements of the source tile, before applying the road type.
@export var source_drivable_width_metres: float = 0.0
@export var source_mesh_height_metres: float = 0.0

@export var road: RoadData:
	set(value): self.bind_line(value)
	get(): return self.entity as RoadData

#region Initialization
## Builds the view from the road type's scene; null for an unknown road type.
static func of(road_data: RoadData) -> RoadWay3D:
	var definition: RoadType = road_data.get_road_type()
	if definition == null:
		return null
	road_data.ensure_curve()
	var view := definition.scene.instantiate() as RoadWay3D
	view.road = road_data
	view.apply_mesh_profile(definition)
	return view

func _enter_tree() -> void:
	# Configure before the child's READY builds the warped mesh. The addon owns
	# the static body and rebuilds it whenever the path/mesh changes.
	get_road_mesh().collision_mode = PathMesh3D.COLLISION_MODE_TRIMESH

func _name_prefix() -> String:
	return "Road"

func _assign_mesh_names(prefix: String, num: int) -> void:
	self.get_road_mesh().name = "%s_%d_Mesh" % [prefix, num]

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
func get_road_mesh() -> PathMesh3D:
	return self.get_child(1)
#endregion
