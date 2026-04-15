@tool
class_name InventoryTransferSideUi extends MarginContainer

@warning_ignore("unused_signal")
signal entity_selected(selected: InventoryEntity3D)

@warning_ignore("unused_signal")
signal side_changed(is_left: bool)

@export var is_left: bool:
	get(): return is_left
	set(value):
		is_left = value
		self.side_changed.emit(value)

@export var dropdown_index: int = 0:
	get(): return dropdown_index
	set(value):
		dropdown_index = value
		if %EntityDropdown:
			%EntityDropdown.select(value)
		
@export_storage var selected_entity: InventoryEntity3D

#region Initialization
func _enter_tree() -> void:
	# connect to side changes
	var side_changed_callable: Callable = Callable(self, "_on_side_changed")
	if !self.side_changed.is_connected(side_changed_callable):
		self.side_changed.connect(side_changed_callable)
	# connect to dropdown selection
	var dropdown_selection_callable: Callable = Callable(self, "_on_entity_dropdown_selection")
	if !%EntityDropdown.item_selected.is_connected(dropdown_selection_callable):
		%EntityDropdown.item_selected.connect(dropdown_selection_callable)

func _ready() -> void:
	if !Engine.is_editor_hint():
		if self.has_node("./VBoxContainer/OuterInventoryList"):
			%OuterInventoryList.queue_free()
		# self._on_entity_dropdown_selection(self.dropdown_index)
#endregion

#region Find Entity
func _find_selected_entity():
	var found_entity: InventoryEntity3D = null
	if self.dropdown_index == 1:
		found_entity = self._find_player()
		

func _find_player() -> PlayerHead:
	return GlobalState.player

func _find_station() -> RailNodeStation3D:
	pass

func find_train() -> Train3D:
	
#endregion

#region Callbacks
func _on_side_changed(_is_left: bool):
	%OuterInventoryList.is_left = _is_left

func _on_entity_dropdown_selection(index: int):
	if !Engine.is_editor_hint() && index >= 0:
		self.dropdown_index = index
		var selected_type_str: String = %EntityDropdown.get_item_text(index)
		Loggie.info("Selected Entity Type: %s" % selected_type_str)
		if !Engine.is_editor_hint():
			self._find_selected_entity()

func _on_selected_entity_found(sel_entity: InventoryEntity3D):
	pass
#endregion
