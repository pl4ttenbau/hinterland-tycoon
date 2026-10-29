@warning_ignore("missing_tool")
@icon("res://assets/icons/icon_play_ui.png")
class_name GameWindow extends Control

#region Initialization
func _enter_tree() -> void:
	SignalBus.map_spawned.connect(Callable(self, "_on_scene_spawned"))
#endregion

#region Callbacks
func _on_scene_spawned(_container: WorldMapScene):
	self.visible = true
#endregion
