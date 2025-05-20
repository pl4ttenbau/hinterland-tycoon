class_name TerrainContainer extends Node3D

@export var terrain: Terrain3D

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
	var y: float = get_height_at(abs_pos)
	return Vector3(abs_pos.x, y, abs_pos.z)
