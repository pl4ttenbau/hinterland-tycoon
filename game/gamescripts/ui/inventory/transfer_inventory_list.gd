@tool
class_name TransferInventoryListUi extends VBoxContainer

@warning_ignore("unused_signal")
signal transfer_out(spawned_good: SpawnedGood)

@warning_ignore("unused_signal")
signal transfer_in(spawned_good: SpawnedGood)

@warning_ignore("unused_signal")
signal side_changed(is_left: bool)

const ROW_SCENE_PATH = "res://scenes/ui/list/inventory_list/inventory_list_row.tscn"

@export var is_left: bool = true:
	get(): return is_left
	set(value):
		is_left = value
		self.side_changed.emit(value)

@export var inventory: GoodsInventory

@export var entity: InventoryEntity3D:
	get(): return entity
	set(value):
		entity = value
		inventory = entity.get_inventory()
		self.fill_inventory_list()

@export var is_ready: bool = false

@export_storage var list_items: Array[TransferInventoryRowUi] = []

#region Initialization
func _ready() -> void:
	var side_changed_callable: Callable = Callable(self, "_on_side_changed")
	if !self.side_changed.is_connected(side_changed_callable):
		self.side_changed.connect(side_changed_callable)
	# remove placeholder
	if !Engine.is_editor_hint():
		for row: TransferInventoryRowUi in self.get_rows():
			row.queue_free()
		self.is_ready = true

func hide_left_right():
	Loggie.info("rows: %s" % self.get_rows())
	
#endregion

#region Inventory List
func fill_inventory_list():
	if self.inventory && self.is_ready:
		for res_key: String in self.inventory.storage.inventory_dict:
			var res_amount: float = self.inventory.get_amount(res_key)
			var new_row: TransferInventoryRowUi = build_inventory_row(res_key, res_amount)
			# connect
			var outer_transfer_callable := Callable(self, "_on_row_out_transfer")
			if !new_row.transfer_out.is_connected(outer_transfer_callable):
				new_row.transfer_out.connect(outer_transfer_callable)
			# and add as child
			%InventoryList.add_child(new_row)

func build_inventory_row(res_key: String, res_amount: float) -> TransferInventoryRowUi:
	var packed_scene: PackedScene = load(ROW_SCENE_PATH)
	var instantiated: TransferInventoryRowUi = packed_scene.instantiate()
	instantiated.res_key = res_key
	instantiated.res_amount = res_amount
	instantiated.is_left = self.is_left
	return instantiated

func get_rows() -> Array[TransferInventoryRowUi]:
	var all_rows: Array[TransferInventoryRowUi] = []
	for list_child: Node in %InventoryList.get_children():
		if list_child is TransferInventoryRowUi:
			all_rows.append(list_child)
	return all_rows
#endregion

#region Callables
func _on_side_changed(_is_left: bool):
	for row: TransferInventoryRowUi in self.get_rows():
		row.is_left = _is_left

func _on_row_out_transfer(_res_key: String, _amount: float):
	var spawned_good := SpawnedGood.new(_res_key, _amount)
	spawned_good.current_location = self.inventory
	self.transfer_out.emit(spawned_good)
#endregion
