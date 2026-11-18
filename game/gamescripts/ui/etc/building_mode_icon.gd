class_name BuildingModeIcon extends MarginContainer

@onready var _cost_label: Label = %TrackCost


func _ready() -> void:
	_cost_label.text = "%s per track segment" % CompanyData.format_cash(CompanyData.TRACK_SEGMENT_COST)
	SignalBus.ui_mode_switched.connect(_on_ui_mode_switched)


func _on_ui_mode_switched(mode: Enums.UiMode) -> void:
	visible = mode == Enums.UiMode.BUILD_INFR
