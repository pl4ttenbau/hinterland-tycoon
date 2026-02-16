class_name SelectedNodeMarker3D extends Node3D

func _ready() -> void:
	SignalBus.building_mode_switched.connect(Callable(self, "_on_building_mode_switch"))
	
func _destroy_again():
	self.queue_free()

func _on_building_mode_switch(enabled: bool):
	if ! enabled:
		self._destroy_again()
