@icon("res://assets/icons/icon_terrain_white.png")
class_name TerrainContainer extends Node

@export var map_key: String
@export var terrain: Terrain3D

signal world_update()

func _enter_tree() -> void:
	# self-register in GlobalState
	GlobalState.terrain = self
	# connect to signals
	self.world_update.connect(Callable(self, "_on_world_update"))

func _ready() -> void:
	var terrain_3d_obj: Terrain3D = self.get_child(0)
	if !terrain_3d_obj:
		Loggie.error("Bei Erstellung des TerrainContainers kann das
		 Terrain3D-Objeckt nicht gefunden werden")
	self.terrain = $WorldTerrain
	SignalBus.terrain_initialized.emit(self)

func get_height_at(abs_pos: Vector3) -> float:
	return self.terrain.data.get_height(abs_pos)

func get_pos_at_height(abs_pos: Vector3) -> Vector3:
	return Vector3(abs_pos.x, get_height_at(abs_pos), abs_pos.z)

func _on_world_update() -> void:
	pass
	
func raycast_xz(world_xz: Vector2) -> TerrainRaycastResult:
	var result: TerrainRaycastResult = $TerrainRaycaster.shoot_ray(world_xz)
	return result
