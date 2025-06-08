class_name IndustrySpawner extends Node

@export_storage var _has_terrain_loaded: bool = false
@export_storage var _has_types_loaded: bool = true

func _enter_tree() -> void:
	pass
	
func _check_requirements_fulfilled(): 
	if !(self._has_terrain_loaded && self._has_types_loaded): return
	self.spawn_industries()
	
func spawn_industries():
	pass

# == LISTENERS == 
func _on_terrain_loaded(terrain_container: TerrainContainer):
	self._has_terrain_loaded = true
	self._check_requirements_fulfilled()
