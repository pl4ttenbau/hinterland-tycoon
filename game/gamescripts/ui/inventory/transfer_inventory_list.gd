@tool
class_name TransferInventoryListUi extends VBoxContainer

signal transfer_out(transfer: GoodsTransfer)

signal side_changed(is_left: bool)

signal entity_changed(entity: InventoryEntity3D)

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
		entity_changed.emit(value)

@export var is_ready: bool = false

@export_storage var list_items: Array[TransferInventoryRowUi] = []

#region Initialization
func _init() -> void:
	# connect to own signals
	var side_changed_callable: Callable = Callable(self, "_on_side_changed")
	if !self.side_changed.is_connected(side_changed_callable):
		self.side_changed.connect(side_changed_callable)
	var entity_changed_callable: Callable = Callable(self, "_on_entity_changed")
	if !self.entity_changed.is_connected(entity_changed_callable):
		self.entity_changed.connect(entity_changed_callable)

func _ready() -> void:
	# remove placeholder
	if !Engine.is_editor_hint():
		self.clean()
		self.is_ready = true

func hide_left_right():
	Loggie.info("rows: %s" % self.get_rows())

func clean():
	for row: TransferInventoryRowUi in self.get_rows():
		row.queue_free()
#endregion

#region Inventory List
func rebuild_inventory_list():
	if self.inventory && self.is_ready:
		self.clean()
		for amount_dto: GoodsAmount in self.inventory.as_goods_amount_list():
			var new_row: TransferInventoryRowUi = build_inventory_row(amount_dto)
			# and add as child
			%InventoryList.add_child(new_row)

func build_inventory_row(_amount_dto: GoodsAmount) -> TransferInventoryRowUi:
	var instantiated: TransferInventoryRowUi = load(ROW_SCENE_PATH).instantiate()
	instantiated.goods_amount = _amount_dto
	instantiated.is_left = self.is_left
	# connect to transfer out signal
	var outer_transfer_callable := Callable(self, "_on_row_out_transfer")
	if !instantiated.transfer_out.is_connected(outer_transfer_callable):
		instantiated.transfer_out.connect(outer_transfer_callable)
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
	var transfer_dto: GoodsTransfer = GoodsTransfer.new(_res_key, _amount, self.entity)
	self.transfer_out.emit(transfer_dto)

func _on_inventory_resource_changed():
	Loggie.info("change in inventory")
	self.rebuild_inventory_list()

func _on_entity_changed(_entity: InventoryEntity3D):
	# save inventory & subscribe to changes in it
	self.inventory = entity.get_inventory()
	self.inventory.resource_change.connect(Callable(self, "_on_inventory_resource_changed"))
	# set entity type label
	var entity_type: Enums.EntityTypes = _entity.entity.type
	var entity_type_name: String = EntityUtils.get_entity_type_enum_name(entity_type)
	%EntityNameLabel.text = entity_type_name
	# rebuild list
	self.rebuild_inventory_list()
#endregion
