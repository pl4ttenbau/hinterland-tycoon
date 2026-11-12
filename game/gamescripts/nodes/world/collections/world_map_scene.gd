## 
@tool
@icon("res://assets/icons/icon_terrain.png")
class_name WorldMapScene extends Node

const MineralGeologySampler = preload("res://game/gamescripts/resources/terrain/mineral_geology.gd")

@export var map_key: String
@export var terrain: Terrain3D

var _mineral_geology: MineralGeologySampler

@warning_ignore("unused_signal")
signal world_update()

#region Initialization
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		var editor_state: HinterlandEditorStateData = get_tree().root.get_node("EditorState")
		if editor_state:
			editor_state.open_world_key = self.map_key
	else:
		# self-register in GlobalState
		GlobalState.world_container = self

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		var editor_state: HinterlandEditorStateData = get_tree().root.get_node("EditorState")
		if editor_state:
			editor_state.open_world_key = ""
			editor_state.open_world = null

func _ready() -> void:
	if Engine.is_editor_hint():
		self._engine_ready()

func _engine_ready() -> void:
	if self.get_tree().root.get_node("EditorState"):
		var editor_state: HinterlandEditorStateData = self.get_tree().root.get_node("/root/EditorState")
		# save terrain & scene in EditorState and fire signal there
		editor_state.open_world = self
		editor_state.terrain3d = self.terrain
		editor_state.world_opened.emit(self)
		print("WorldMap \"%s\" finished opening" % self.map_key)
#endregion

#region Terrain Getters
func get_height_at(abs_pos: Vector3) -> float:
	return self.terrain.data.get_height(abs_pos)

func get_pos_at_height(abs_pos: Vector3) -> Vector3:
	return Vector3(abs_pos.x, get_height_at(abs_pos), abs_pos.z)

func sample_minerals_at(abs_pos: Vector3) -> Dictionary[String, float]:
	if _mineral_geology == null:
		# The exporter uses the same map seed, so both paths sample the same fields.
		_mineral_geology = MineralGeologySampler.new(map_key.hash())
	if terrain == null:
		return _mineral_geology.sample(abs_pos)
	return _mineral_geology.sample(abs_pos, terrain.data, terrain.assets)
	
func get_terrain() -> Terrain3D:
	return self.get_child(0)
	
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
