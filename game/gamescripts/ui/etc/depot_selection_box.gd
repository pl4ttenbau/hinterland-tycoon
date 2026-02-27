class_name DepotSelectionBox extends MarginContainer

signal depot_selected(depot: RailDepotData)

@export var container: BoxContainer

@export var depot: RailDepotData:
	set(value):
		depot = value
		self.update_text()
		
func _ready():
	%Button.button_down.connect(Callable(self, "_on_depot_selection_click"))

func update_text():
	$Button.text = self.depot.get_display_letter()

#region Select & Unselect
func _on_depot_selection_click():
	self.depot_selected.emit(self.depot)
	self.modulate = Color(0, 1, 0, 1)
	self._unselect_others()

func _unselect():
	self.modulate = Color(1, 1, 1, 1)
	
func _unselect_others():
	for sibling: Node in self.get_parent().get_children():
		if sibling == self: continue
		if sibling is DepotSelectionBox:
			sibling._unselect()
#endregion
