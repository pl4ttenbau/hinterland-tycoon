class_name BuildingModeIcon extends MarginContainer

func _ready() -> void:
	SignalBus.building_mode_switched.connect(Callable(self, "_on_building_mode_switched"))
	
func _on_building_mode_switched(enabled: bool):
	self.visible = enabled

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		self.disable_building_mode()
		get_viewport().set_input_as_handled()
			
func disable_building_mode():
	UiState.building_mode_on = false
	SignalBus.building_mode_switched.emit(false)
