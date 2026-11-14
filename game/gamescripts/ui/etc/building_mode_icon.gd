class_name BuildingModeIcon extends MarginContainer

@onready var _cost_label: Label = %TrackCost


func _ready() -> void:
	var company := CompanyData.current()
	if company != null:
		company.changed.connect(_update_cost)
	_update_cost()
	SignalBus.ui_mode_switched.connect(Callable(self, "_on_ui_mode_switched"))
	
func _on_ui_mode_switched(mode: Enums.UiMode):
	if mode == Enums.UiMode.BUILD_INFR:
		self.visible = true
	else:
		self.visible = false

func _update_cost() -> void:
	var company := CompanyData.current()
	_cost_label.text = "%s per track segment" % CompanyData.format_cash(CompanyData.TRACK_SEGMENT_COST)
	if company != null and not company.spending_error(CompanyData.TRACK_SEGMENT_COST).is_empty():
		_cost_label.text += " · Insufficient funds"


func _input(event: InputEvent) -> void:
	if UiState.ui_mode == Enums.UiMode.BUILD_INFR and not UiState.is_world_input_blocked() \
			and event.is_action_pressed("ui_cancel"):
		self.disable_building_mode()
		get_viewport().set_input_as_handled()

func disable_building_mode():
	UiState.ui_mode = Enums.UiMode.WALKING
	SignalBus.ui_mode_switched.emit(Enums.UiMode.WALKING)
