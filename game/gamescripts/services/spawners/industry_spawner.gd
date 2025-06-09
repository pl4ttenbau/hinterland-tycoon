class_name IndustrySpawner extends Node

@export_storage var _has_terrain_loaded: bool = false
@export_storage var _has_types_loaded: bool = true

func _enter_tree() -> void:
	SignalBus.terrain_initialized.connect(Callable(self, "_on_terrain_loaded"))
	SignalBus.all_types_initialized.connect(Callable(self, "_on_all_types_loaded"))
	
func _check_requirements_fulfilled(): 
	if !(self._has_terrain_loaded && self._has_types_loaded): return
	self.spawn_industries()
	
func spawn_industries():
	Loggie.info("ready to spawn industries")

# == LISTENERS == 
func _on_terrain_loaded(terrain_container: TerrainContainer):
	self._has_terrain_loaded = true
	self._check_requirements_fulfilled()
	
func _on_all_types_loaded():
	self._has_types_loaded = true
	self._check_requirements_fulfilled()
