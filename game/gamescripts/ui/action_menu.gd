class_name ActionMenu extends VBoxContainer

@export_storage var current_item_index: int = 0
@export var items: Array[ActionMenuItem] = []
@export var selected_item: ActionMenuItem

signal current_item_changed(i: int)

func _enter_tree() -> void:
	self.current_item_changed.connect(Callable(self, "_current_item_changed"))

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self._cache_children()

func _shortcut_input(event: InputEvent) -> void:
	if event.is_pressed() == true:
		var as_text: String = event.as_text()
		if as_text == "Tab":
			self.current_item_changed.emit(self.current_item_index +1)
		elif as_text == "E":
			SignalBus.action_menu_triggered.emit(self.selected_item)
		
func _current_item_changed(_i: int):
	if self.selected_item:
		self.selected_item.unselected.emit()
	# select new one
	self._select_next_item()
	
func _select_next_item():
	self.current_item_index += 1
	self.selected_item = self.get_item_by_index(current_item_index)
	self.selected_item.selected.emit()

func _cache_children() -> void:
	for child: Control in self.get_children():
		if child is ActionMenuItem:
			self.items.append(child)
	
func get_item_by_index(i: int) -> ActionMenuItem:
	var real_i: int = i % self.items.size()
	return self.items[real_i]
