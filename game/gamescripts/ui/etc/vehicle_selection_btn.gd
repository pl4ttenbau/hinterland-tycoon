@tool
class_name VehicleSelectionButton extends Control

@export var headline_text: String:
	get(): return headline_text
	set(value):
		headline_text = value
		self.headline.text = value

@export var veh_type_key: String

@export var button: Button:
	get(): 
		return $MarginContainer/VBoxContainer/Button as Button

@export var headline: Label:
	get(): return $MarginContainer/VBoxContainer/VehTypeLabel

func _ready() -> void:
	self.button.pressed.connect(Callable(self, "_on_button_pressed"))
	
func _on_button_pressed() -> void:
	Loggie.info("Vehicle Selected: %s" % self.headline_text)
	SignalBus.dialog_vehicle_selection.emit(self.veh_type_key)
