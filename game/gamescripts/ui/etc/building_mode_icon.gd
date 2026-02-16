class_name BuildingModeIcon extends MarginContainer

func _ready() -> void:
	SignalBus.building_mode_switched.connect(Callable(self, "_on_building_mode_switched"))
	
func _on_building_mode_switched(enabled: bool):
	self.visible = enabled

func _input(event: InputEvent) -> void:
	if event is InputEventKey && UiState.building_mode_on:
		if event.pressed && event.keycode == KEY_ESCAPE:
			self.disable_building_mode()
			
func disable_building_mode():
	UiState.building_mode_on = false
	SignalBus.building_mode_switched.emit(false)
