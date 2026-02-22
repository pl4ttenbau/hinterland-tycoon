class_name DepotSelectionBox extends MarginContainer

signal depot_selected(depot: RailDepotData)

@export var depot: RailDepotData:
	set(value):
		depot = value
		self.update_text()
		
func _ready():
	%Button.pressed.connect(Callable(self, "_on_depot_selection_click"))

func update_text():
	$Button.text = self.depot.get_display_letter()
	
func _on_depot_selection_click():
	self.depot_selected.emit(self.depot)
