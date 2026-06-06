class_name StationSignPanel extends PanelContainer

const HIDE_EMPTY_GOOD_TYPES: bool = false

signal passengers_amount_changed(passengers_amount: int)
signal cargo_amount_changed(cargo_amount: int)

@export var station_name: String:
	get(): return station_name
	set(value):
		station_name = value
		%StationNameLabel.text = value

@export var passengers_amount: int:
	get(): return passengers_amount
	set(value):
		passengers_amount = value
		passengers_amount_changed.emit(value)

@export var cargo_amount: int:
	get(): return cargo_amount
	set(value):
		cargo_amount = value
		cargo_amount_changed.emit(value)

@export var cargo_label: Label
@export var passenger_label: Label

#region Initialization
func _ready() -> void:
	self.passengers_amount_changed.connect(Callable(self, "_on_passengers_amount_changed"))
	self.cargo_amount_changed.connect(Callable(self, "_on_cargo_amount_changed"))
	# initialize to hide both
	self.passengers_amount = 0
	self.cargo_amount = 0
#endregion

#region Callbacks
func _on_passengers_amount_changed(amount: int):
	self.passenger_label.text = str(amount)
	if HIDE_EMPTY_GOOD_TYPES && amount <= 0:
		self.passenger_label.visible = false

func _on_cargo_amount_changed(amount: int):
	self.cargo_label.text = str(amount)
	if HIDE_EMPTY_GOOD_TYPES && amount <= 0:
		self.cargo_label.visible = false
#endregion
