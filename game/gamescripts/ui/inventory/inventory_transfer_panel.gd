## Reusable endpoint picker + capacity + searchable passenger/cargo table.
## Layout lives in inventory_transfer_panel.tscn.
class_name InventoryTransferPanel extends VBoxContainer

signal selection_changed()
signal activated()

var endpoint: InventoryEndpoint
var selected_stack: InventoryStack
var passengers: bool = false
var _endpoints: Array[InventoryEndpoint] = []
var _inventory: GoodsInventory

@onready var _picker: OptionButton = %Picker
@onready var _capacity: Label = %Capacity
@onready var _meter: ProgressBar = %Meter
@onready var _search: LineEdit = %Search
@onready var _table: Tree = %Table
@onready var _empty: Label = %Empty

func _ready() -> void:
	_picker.item_selected.connect(_on_endpoint_selected)
	_search.text_changed.connect(_on_search_text_changed)
	_table.item_selected.connect(_on_row_selected)

func _on_search_text_changed(_text: String) -> void:
	_refresh()

func set_endpoints(items: Array[InventoryEndpoint], selected: int) -> void:
	_endpoints = items
	_picker.clear()
	for item: InventoryEndpoint in items:
		_picker.add_item(item.label)
	_picker.disabled = items.is_empty()
	_picker.select(selected if selected >= 0 and selected < items.size() else -1)
	_bind(_picker.selected)

func set_passengers(enabled: bool) -> void:
	passengers = enabled
	_search.placeholder_text = "Filter passengers or destinations" if enabled else "Filter cargo"
	_refresh()

func _on_endpoint_selected(index: int) -> void:
	_bind(index)
	activated.emit()

## Track only the selected resource. Rebinding/removal always releases the old listener.
func _bind(index: int) -> void:
	_disconnect_inventory()
	endpoint = _endpoints[index] if index >= 0 and index < _endpoints.size() else null
	_inventory = endpoint.inventory() if endpoint != null else null
	selected_stack = null
	if _inventory != null:
		_inventory.goods_change.connect(_on_inventory_changed)
	_refresh()

func _on_inventory_changed() -> void:
	# Defer table replacement until the input event/transaction has finished.
	_refresh.call_deferred()

func _refresh() -> void:
	if _table == null:
		return
	var identity: String = selected_stack.identity() if selected_stack != null else ""
	selected_stack = null
	_table.clear()
	_table.columns = 3 if passengers else 2
	# Reset widths when switching back from cargo's fixed quantity column.
	for column: int in range(_table.columns):
		_table.set_column_expand(column, true)
		_table.set_column_custom_minimum_width(column, 0)
	_table.set_column_title(0, "Passenger" if passengers else "Resource")
	if passengers:
		_table.set_column_custom_minimum_width(0, 145)
		_table.set_column_title(1, "Destination")
	_table.set_column_title(_table.columns - 1, "Qty")
	_table.set_column_expand(_table.columns - 1, false)
	_table.set_column_custom_minimum_width(_table.columns - 1, 75)
	var root: TreeItem = _table.create_item()
	if endpoint != null and endpoint.available():
		for stack: InventoryStack in _inventory.stacks(passengers):
			_add_row(root, stack, identity)
	_refresh_capacity()
	# Reserve the same footer height in both panels so the tables stay aligned.
	_empty.text = ("No matching passengers." if passengers else "No matching cargo.") if root.get_first_child() == null else ""
	selection_changed.emit()

func _add_row(root: TreeItem, stack: InventoryStack, selected: String) -> void:
	var title: String = str(stack.good_key).capitalize()
	var destination: String = InventoryPresentation.destination(stack.destination_interchange)
	if not _search.text.is_empty() and not (title + " " + destination).containsn(_search.text):
		return
	var row: TreeItem = _table.create_item(root)
	row.set_text(0, title)
	row.set_tooltip_text(0, title)
	row.set_icon(0, InventoryPresentation.icon(stack.good_key))
	row.set_icon_max_width(0, 36)
	row.set_custom_minimum_height(44)
	row.set_metadata(0, stack)
	if passengers:
		row.set_text(1, destination)
		row.set_tooltip_text(1, destination)
	var quantity_column: int = _table.columns - 1
	row.set_text(quantity_column, InventoryPresentation.quantity(stack.amount))
	row.set_text_alignment(quantity_column, HORIZONTAL_ALIGNMENT_RIGHT)
	if stack.identity() == selected:
		row.select(0)
		selected_stack = stack

func _refresh_capacity() -> void:
	if endpoint == null or not endpoint.available():
		_capacity.text = "No inventory selected"
		_meter.value = 0
		return
	var data: GoodsInventory = endpoint.inventory()
	_capacity.text = "%s / %s units used" % [InventoryPresentation.quantity(data.storage.current_storage), InventoryPresentation.quantity(data.amount_max)]
	_meter.value = 100.0 * data.storage.current_storage / data.amount_max if data.amount_max > 0 else 0

func _on_row_selected() -> void:
	var row: TreeItem = _table.get_selected()
	selected_stack = row.get_metadata(0) if row != null else null
	selection_changed.emit()
	activated.emit()

func _process(_delta: float) -> void:
	if endpoint != null and not endpoint.available():
		_picker.select(-1)
		_bind(-1)

func _disconnect_inventory() -> void:
	if _inventory != null and _inventory.goods_change.is_connected(_on_inventory_changed):
		_inventory.goods_change.disconnect(_on_inventory_changed)

func _exit_tree() -> void:
	_disconnect_inventory()
