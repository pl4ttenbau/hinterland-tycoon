class_name FeatureMockContainer extends Node3D

func _enter_tree() -> void:
	SignalBus.map_spawned.connect(Callable(self, "_on_terrain_loaded"))

func remove_all_children():
	for child in self.get_children():
		child.queue_free()

func _on_terrain_loaded(_terrain_container: TerrainContainer):
	self.remove_all_children()
