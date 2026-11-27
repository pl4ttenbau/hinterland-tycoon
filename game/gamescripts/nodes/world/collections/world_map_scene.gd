## 
@tool
@icon("res://assets/icons/icon_terrain.png")
class_name WorldMapScene extends Node

const MineralGeologySampler = preload("res://game/gamescripts/resources/terrain/mineral_geology.gd")
const TerrainVegetation = preload("res://game/gamescripts/nodes/world/terrain_grass.gd")

@export var map_key: String
@export var terrain: Terrain3D

var _mineral_geology: MineralGeologySampler

@warning_ignore("unused_signal")
signal world_update()

#region Initialization
func _enter_tree() -> void:
	## In game the map registers itself; the editor plugin tracks the open map on its own (active_world).
	if not Engine.is_editor_hint():
		GlobalState.world_container = self
#endregion

#region Terrain Getters
func get_height_at(abs_pos: Vector3) -> float:
	return self.terrain.data.get_height(abs_pos)

func get_pos_at_height(abs_pos: Vector3) -> Vector3:
	return Vector3(abs_pos.x, get_height_at(abs_pos), abs_pos.z)

## Update this world's grass and wheat coverage along the completed ballast footprint.
func clear_rail_vegetation(curve: Curve3D, half_width: float) -> void:
	if not is_instance_valid(terrain):
		return
	var footprint := curve.duplicate() as Curve3D
	footprint.bake_interval = 1.0
	footprint.up_vector_enabled = false
	var points: PackedVector3Array = footprint.get_baked_points()
	for node: Node in get_tree().get_nodes_in_group(&"_terrain_vegetation"):
		if node is TerrainVegetation and node.terrain == terrain:
			node.clear_along_rail(points, half_width)

func sample_minerals_at(abs_pos: Vector3) -> Dictionary[String, float]:
	if _mineral_geology == null:
		# The exporter uses the same map seed, so both paths sample the same fields.
		_mineral_geology = MineralGeologySampler.new(map_key.hash())
	if terrain == null:
		return _mineral_geology.sample(abs_pos)
	return _mineral_geology.sample(abs_pos, terrain.data, terrain.assets)
	
func raycast_xz(world_xz: Vector2) -> TerrainRaycastResult:
	var result: TerrainRaycastResult = $TerrainRaycaster.shoot_ray(world_xz)
	return result
#endregion

func _get_configuration_warnings() -> PackedStringArray:
	var child_err_msgs: PackedStringArray = []
	if !$WorldTerrain:
		child_err_msgs.append("WorldTerrain (Terrain3D) child node missing")
	if !$Towns:
		child_err_msgs.append("Towns (WorldTowns) child node missing")
	if !$Industries:
		child_err_msgs.append("Industries (WorldIndustries) child node missing")
	if !$EditorObjects:
		child_err_msgs.append("EditorObjects (EditorObjectContainer) child node missing")
	return child_err_msgs
