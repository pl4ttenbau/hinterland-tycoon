class_name BuildingModeIcon extends MarginContainer

func _ready() -> void:
	SignalBus.ui_mode_switched.connect(Callable(self, "_on_ui_mode_switched"))
	
func _on_ui_mode_switched(mode: Enums.UiMode):
	if mode == Enums.UiMode.BUILD_INFR:
		self.visible = true
	else:
		self.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		self.disable_building_mode()
		get_viewport().set_input_as_handled()

func disable_building_mode():
	UiState.ui_mode = Enums.UiMode.WALKING
	SignalBus.ui_mode_switched.emit(Enums.UiMode.WALKING)
