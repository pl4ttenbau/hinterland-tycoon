class_name StationSignPanel extends PanelContainer

@export var station_name: String:
	get(): return station_name
	set(value):
		station_name = value
		%StationNameLabel.text = value
		
@export var res_amount: int:
	get(): return res_amount
	set(value):
		res_amount = value
		%ResourceAmountLabel.text = value

func _ready() -> void:
	self.station_name_label = %StationNameLabel
	self.res_amount_label = %ResourceAmountLabel
