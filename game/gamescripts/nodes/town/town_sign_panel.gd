class_name TownSignPanel extends PanelContainer

@export var town_name: String:
	get(): return town_name
	set(value):
		town_name = value
		%TownNameLabel.text = value
		
@export var pops_amount: int:
	get(): return pops_amount
	set(value):
		pops_amount = value
		%PopsAmountLabel.text = str(value)
