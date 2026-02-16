class_name SelectedNodeMarker3D extends Node3D

func _ready() -> void:
	SignalBus.ui_mode_switched.connect(Callable(self, "_on_ui_mode_switched"))
	
func _destroy_again():
	self.queue_free()

func _on_ui_mode_switched(mode: Enums.UiMode):
	if ! mode == Enums.UiMode.BUILD_INFR:
		self._destroy_again()
