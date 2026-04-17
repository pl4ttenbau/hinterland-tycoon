@tool
class_name InventoryTransferSideUi extends MarginContainer

@warning_ignore("unused_signal")
signal entity_selected(selected: InventoryEntity3D)

@warning_ignore("unused_signal")
signal side_changed(is_left: bool)

const INVENTORY_LIST_SCENE = "res://scenes/ui/list/inventory_list/inventory_list.tscn"
const INVENTORY_LIT_NAME = "OuterInventoryList"

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

@export var selected_entity: InventoryEntity3D

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
	self.clear_inventory_list()
	# connect to SelectedEntityFinder
	var selected_entity_callable = Callable(self, "_on_selected_entity_found")
	if !$SelectedEntityFinder.selected_entity_found.is_connected(selected_entity_callable):
		$SelectedEntityFinder.selected_entity_found.connect(selected_entity_callable)
#endregion

#region Inventory Building
func build_inventory_list():
	self.clear_inventory_list()
	if self.selected_entity:
		var packed: PackedScene = load(INVENTORY_LIST_SCENE)
		var inv_list: TransferInventoryListUi = packed.instantiate()
		$VBoxContainer.add_child(inv_list)
		inv_list.name = INVENTORY_LIT_NAME
		inv_list.is_left = self.is_left
		inv_list.entity = self.selected_entity
		inv_list.inventory = self.selected_entity.get_inventory()

func clear_inventory_list():
	if !Engine.is_editor_hint():
		if $VBoxContainer.has_node("./OuterInventoryList"):
			$VBoxContainer/OuterInventoryList.queue_free()
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
			$SelectedEntityFinder.find_selected_entity_by_index(index)

func _on_selected_entity_found(sel_entity: InventoryEntity3D):
	self.selected_entity = sel_entity
	self.build_inventory_list()
#endregion
