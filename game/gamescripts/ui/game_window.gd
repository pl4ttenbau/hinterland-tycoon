@warning_ignore("missing_tool")
@icon("res://assets/icons/icon_play_ui.png")
class_name GameWindow extends Control

func _enter_tree() -> void:
	SignalBus.map_spawned.connect(Callable(self, "_on_scene_spawned"))
	
func _on_scene_spawned(_container: WorldMapScene):
	self.visible = true
