class_name IndustrySignPanel extends PanelContainer

@export var industry_name: String:
	get(): return industry_name
	set(value):
		industry_name = value
		%StationNameLabel.text = value
		
@export var res_amount: int:
	get(): return res_amount
	set(value):
		res_amount = value
		%ResourceAmountLabel.text = str(value)
