## Platform type, side and visibility for a rail stop.
class_name RailPlatformOptions extends VBoxContainer

signal platform_type_changed(station_type: String)
signal layout_changed(side: RailStationData.PlatformSide, hidden: bool)

## Station types in PlatformType item order.
const STATION_TYPES: Array[String] = ["STATION_PASS", "STATION_GOODS"]

@onready var _type: OptionButton = %PlatformType
@onready var _side: OptionButton = %PlatformSide
@onready var _hide: CheckBox = %HidePlatform

func _ready() -> void:
	# 1. Wiring: side and visibility both reshape the same preview.
	_type.item_selected.connect(_on_platform_type_item_selected)
	_side.item_selected.connect(_on_layout_input_changed)
	_hide.toggled.connect(_on_layout_input_changed)
	# 2. Initial state: items come from the scene; make sure one is selected.
	for option: OptionButton in [_type, _side]:
		if option.selected < 0:
			option.select(0)

func station_type() -> String:
	return STATION_TYPES[_type.selected]

## Restores the type selection without emitting, e.g. when its preview is unavailable.
func select_type(value: String) -> void:
	_type.select(STATION_TYPES.find(value))

func side() -> RailStationData.PlatformSide:
	return _side.get_selected_id() as RailStationData.PlatformSide

func is_platform_hidden() -> bool:
	return _hide.button_pressed

func focus() -> void:
	_type.grab_focus()

func _on_platform_type_item_selected(_index: int) -> void:
	platform_type_changed.emit(station_type())

func _on_layout_input_changed(_value: Variant) -> void:
	layout_changed.emit(side(), is_platform_hidden())
