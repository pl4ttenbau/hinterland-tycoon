@warning_ignore("missing_tool")
class_name GameWindow extends Control

func _enter_tree() -> void:
	SignalBus.map_spawned.connect(Callable(self, "_on_scene_spawned"))
	
func _on_scene_spawned(_container: TerrainContainer):
	self.visible = true
