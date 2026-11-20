## Moves goods or passengers between two inventories near the player, e.g. the
## truck they drive and the stop it stands at. Each side is an
## InventoryTransferPanel: pick an inventory, then a row (a stack of one good,
## or passengers for one destination). The middle column moves a quantity of the
## selected row to the other side.
##
## Coordinates the two panels, the Passengers/Cargo tabs and the transfer
## controls. InventoryTransferService owns all stock mutation and every rule
## about what may move; layout lives in transfer_inventory_dialog.tscn.
class_name InventoryTransferDialog extends ModalGameDialog

## Tests/previews can supply components without requiring a running map.
var available_endpoints: Array[InventoryEndpoint] = []
var _selection_service := InventorySelectionService.new()
## The side the player touched last (0 = left, 1 = right). Max and the hint use
## its selected row as the source; the move buttons name their own direction.
var _active_side: int = 0

@onready var _panel: PanelContainer = %Panel
@onready var _tabs: InventoryCategoryTabs = %Tabs
@onready var _left: InventoryTransferPanel = %LeftPanel
@onready var _right: InventoryTransferPanel = %RightPanel
@onready var _quantity: SpinBox = %Quantity
@onready var _maximum: Button = %MaxButton
@onready var _move_right: Button = %MoveRightButton
@onready var _move_left: Button = %MoveLeftButton
@onready var _hint: Label = %Hint

func _ready() -> void:
	# 1. Wiring.
	_connect_signals()
	# 2. Content: nearby inventories on both sides.
	_refresh_available()
	# 3. Initial state: start on Passengers when the left side carries them, else Cargo.
	var passenger_default: bool = _left.endpoint != null and BaseGoodsType.ResourceCategory.PASSENGER in _left.endpoint.component().accepted_categories
	_tabs.current_tab = 0 if passenger_default else 1
	_set_mode(_tabs.current_tab)
	# 4. Layout: fit the window now and whenever it resizes.
	_resize_dialog()
	get_viewport().size_changed.connect(_resize_dialog)

#region Layout and wiring
func _connect_signals() -> void:
	_tabs.tab_changed.connect(_set_mode)
	for panel: InventoryTransferPanel in [_left, _right]:
		panel.selection_changed.connect(_update_controls)
	_left.activated.connect(_on_left_activated)
	_right.activated.connect(_on_right_activated)
	_quantity.value_changed.connect(_on_quantity_changed)
	_maximum.pressed.connect(_set_maximum)
	_move_right.pressed.connect(_on_move_right_pressed)
	_move_left.pressed.connect(_on_move_left_pressed)
	%RefreshButton.pressed.connect(_refresh_available)
	%CloseButton.pressed.connect(close_all)

## Grow with the window, but keep a margin around the panel.
func _resize_dialog() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	_panel.custom_minimum_size = Vector2(minf(1140, viewport.x - 48), minf(740, viewport.y - 48))

func _on_left_activated() -> void:
	_active_side = 0
	_update_controls()

func _on_right_activated() -> void:
	_active_side = 1
	_update_controls()

func _on_quantity_changed(_value: float) -> void:
	_update_controls()

func _on_move_right_pressed() -> void:
	_transfer(_left, _right)

func _on_move_left_pressed() -> void:
	_transfer(_right, _left)
#endregion

#region Endpoint and row selection
## Rediscovers nearby inventories, e.g. after the player walked to another stop.
## Keeps each side on the same inventory if it is still around; otherwise the
## left side falls back to the first entry and the right side to a stop.
func _refresh_available() -> void:
	var left_id: int = _inventory_id(_left.endpoint)
	var right_id: int = _inventory_id(_right.endpoint)
	var items: Array[InventoryEndpoint] = available_endpoints if not available_endpoints.is_empty() else _selection_service.discover()
	var left: int = _find_inventory(items, left_id, 0)
	var right: int = _find_inventory(items, right_id, _default_right(items, left))
	_left.set_endpoints(items, left)
	_right.set_endpoints(items, right)
	_update_controls()

## Identity of the inventory behind an endpoint. Endpoint objects are rebuilt on
## every discovery, so sides are matched by the inventory instance instead.
func _inventory_id(endpoint: InventoryEndpoint) -> int:
	return endpoint.inventory().get_instance_id() if endpoint != null and endpoint.available() else -1

func _find_inventory(items: Array[InventoryEndpoint], id: int, fallback: int) -> int:
	for index: int in range(items.size()):
		if _inventory_id(items[index]) == id:
			return index
	return fallback if fallback < items.size() else -1

## The left side usually starts on the player or their vehicle; the most likely
## partner is a stop, so the right side prefers one, then anything else.
func _default_right(items: Array[InventoryEndpoint], left: int) -> int:
	for index: int in range(items.size()):
		if index != left and items[index].kind == InventoryEndpoint.Kind.STOP:
			return index
	for index: int in range(items.size()):
		if index != left:
			return index
	return -1

## Switches between Passengers (tab 0) and Cargo (tab 1). Passengers move in
## whole people; cargo in tenths of a unit.
func _set_mode(index: int) -> void:
	if _left == null or _right == null:
		return
	var passengers: bool = index == 0
	_quantity.min_value = 1.0 if passengers else 0.1
	_quantity.step = 1.0 if passengers else 0.1
	_quantity.rounded = passengers
	_left.set_passengers(passengers)
	_right.set_passengers(passengers)
	_update_controls()

## Re-checks both directions after any change of selection or quantity: each
## move button is enabled only if that transfer would succeed, and its tooltip
## says why not. The hint shows how much of the active side's row can move.
func _update_controls() -> void:
	if _right == null or _move_left == null:
		return
	var left_error: String = InventoryTransferService.validate(_left.endpoint, _right.endpoint, _left.selected_stack, _quantity.value)
	var right_error: String = InventoryTransferService.validate(_right.endpoint, _left.endpoint, _right.selected_stack, _quantity.value)
	_move_right.disabled = not left_error.is_empty()
	_move_right.tooltip_text = left_error
	_move_left.disabled = not right_error.is_empty()
	_move_left.tooltip_text = right_error
	var source: InventoryTransferPanel = _left if _active_side == 0 else _right
	var target: InventoryTransferPanel = _right if _active_side == 0 else _left
	var maximum: float = InventoryTransferService.maximum(source.endpoint, target.endpoint, source.selected_stack)
	_maximum.disabled = maximum <= 0
	_hint.text = "Select a row on either side."
	if source.selected_stack != null:
		_hint.text = "%s\nUp to %s can move" % [str(source.selected_stack.good_key).capitalize(), InventoryPresentation.quantity(maximum)]
		if maximum <= 0:
			_hint.text = left_error if _active_side == 0 else right_error

## Max: the most of the active side's selected row the other side can take.
func _set_maximum() -> void:
	var source: InventoryTransferPanel = _left if _active_side == 0 else _right
	var target: InventoryTransferPanel = _right if _active_side == 0 else _left
	var maximum: float = InventoryTransferService.maximum(source.endpoint, target.endpoint, source.selected_stack)
	if maximum > 0:
		_quantity.value = maximum
#endregion

#region Transfer commands
## Moves the quantity of source's selected row to target and reports the result.
## Passengers that reach their destination interchange count as arrived and do
## not join the waiting stock there, hence the separate message.
func _transfer(source: InventoryTransferPanel, target: InventoryTransferPanel) -> void:
	var stack: InventoryStack = source.selected_stack
	var amount: float = _quantity.value
	var destination_label: String = target.endpoint.label if target.endpoint != null else ""
	var completes_trip: bool = InventoryTransferService.completes_passenger_trip(target.endpoint, stack)
	var error: String = InventoryTransferService.transfer(source.endpoint, target.endpoint, stack, amount)
	if not error.is_empty():
		show_status(error, StatusTone.ERROR)
		return
	var quantity_text: String = InventoryPresentation.quantity(amount)
	if completes_trip:
		show_status("%s %s arrived at %s." % [quantity_text, str(stack.good_key).capitalize(), destination_label], StatusTone.SUCCESS)
	else:
		show_status("Moved %s %s to %s." % [quantity_text, str(stack.good_key).capitalize(), destination_label], StatusTone.SUCCESS)
	_update_controls()
#endregion
