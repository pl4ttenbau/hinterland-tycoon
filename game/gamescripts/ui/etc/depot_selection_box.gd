class_name DepotSelectionBox extends MarginContainer

@export var depot: RailDepotData:
	set(value):
		depot = value
		self.update_text()

func update_text():
	$Button.text = self.depot.get_display_letter()
