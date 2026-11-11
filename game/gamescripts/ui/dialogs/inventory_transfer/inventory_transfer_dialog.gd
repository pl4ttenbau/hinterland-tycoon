## Coordinates reusable panels and a transfer service. No stock mutation lives in this UI.
class_name InventoryTransferDialog extends ModalGameDialog

## Tests/previews can supply components without requiring a running map.
var available_endpoints: Array[InventoryEndpoint] = []
var _selection_service := InventorySelectionService.new()
var _left: InventoryTransferPanel
var _right: InventoryTransferPanel
var _tabs: InventoryCategoryTabs
var _quantity: SpinBox
var _maximum: Button
var _move_right: Button
var _move_left: Button
var _hint: Label
var _status: Label
var _overlay: ColorRect
var _active_side: int = 0

func _ready() -> void:
	dialog_key = "InventoryTransferDiag"
	title_text = "Transfer inventory"
	_suspend_world_input()
	_build_layout()
	_refresh_available()
	var passenger_default: bool = _left.endpoint != null and BaseGoodsType.ResourceCategory.PASSENGER in _left.endpoint.component().accepted_categories
	_tabs.current_tab = 0 if passenger_default else 1
	_set_mode(_tabs.current_tab)
	_resize_dialog.call_deferred()
	get_viewport().size_changed.connect(_resize_dialog)

#region Composition and layout
func _build_layout() -> void:
	# Replace only the old content; keep the existing themed frame, title and close button.
	var content: Node = get_node("OuterPanel/OuterMargin/OuterVLayout/Container")
	for child: Node in content.get_children():
		child.free()
	get_node("OuterPanel/OuterMargin").custom_minimum_size = Vector2.ZERO
	get_node("OuterPanel/OuterMargin/OuterVLayout").custom_minimum_size = Vector2.ZERO
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.38)
	add_child(_overlay)
	move_child(_overlay, 0)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	content.add_child(layout)
	_build_toolbar(layout)
	_build_panels(layout)
	_build_footer(layout)

func _build_toolbar(layout: VBoxContainer) -> void:
	_tabs = InventoryCategoryTabs.new()
	_tabs.tab_changed.connect(_set_mode)
	layout.add_child(_tabs)

func _build_panels(layout: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(row)
	_left = InventoryTransferPanel.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_left)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size.x = 150
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(controls)
	_build_transfer_controls(controls)
	_right = InventoryTransferPanel.new()
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_right)
	_left.selection_changed.connect(_update_controls)
	_right.selection_changed.connect(_update_controls)
	_left.activated.connect(func(): _active_side = 0; _update_controls())
	_right.activated.connect(func(): _active_side = 1; _update_controls())

func _build_transfer_controls(box: VBoxContainer) -> void:
	var caption := Label.new()
	caption.text = "Quantity"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	_quantity = SpinBox.new()
	_quantity.min_value = 0.1
	_quantity.max_value = 1000000
	_quantity.step = 0.1
	_quantity.value = 1
	_quantity.value_changed.connect(func(_value: float): _update_controls())
	box.add_child(_quantity)
	_maximum = _button(box, "Max", _set_maximum)
	_move_right = _button(box, "Move right →", func(): _transfer(_left, _right))
	_move_left = _button(box, "← Move left", func(): _transfer(_right, _left))
	_move_right.theme_type_variation = &"PrimaryButton"
	_move_left.theme_type_variation = &"PrimaryButton"
	_hint = Label.new()
	_hint.custom_minimum_size.x = 150
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.theme_type_variation = &"MutedLabel"
	box.add_child(_hint)

func _build_footer(layout: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	layout.add_child(row)
	_status = Label.new()
	_status.text = "Select a resource, choose a quantity, then move it."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	_button(row, "Refresh nearby", _refresh_available)
	var close: Button = get_node("%CloseButton")
	close.theme_type_variation = &"ManagementButton"
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(close_all)

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"ManagementButton"
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _resize_dialog() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	var extent := Vector2(minf(1140, viewport.x - 48), minf(740, viewport.y - 48)) * 0.5
	var panel: Control = get_node("OuterPanel")
	panel.offset_left = -extent.x
	panel.offset_right = extent.x
	panel.offset_top = -extent.y
	panel.offset_bottom = extent.y
	_overlay.position = -global_position
	_overlay.size = viewport
#endregion

#region Endpoint and row selection
func _refresh_available() -> void:
	var left_id: int = _inventory_id(_left.endpoint)
	var right_id: int = _inventory_id(_right.endpoint)
	var items: Array[InventoryEndpoint] = available_endpoints if not available_endpoints.is_empty() else _selection_service.discover()
	var left: int = _find_inventory(items, left_id, 0)
	var right: int = _find_inventory(items, right_id, _default_right(items, left))
	_left.set_endpoints(items, left)
	_right.set_endpoints(items, right)
	_update_controls()

func _inventory_id(endpoint: InventoryEndpoint) -> int:
	return endpoint.inventory().get_instance_id() if endpoint != null and endpoint.available() else -1

func _find_inventory(items: Array[InventoryEndpoint], id: int, fallback: int) -> int:
	for index: int in range(items.size()):
		if _inventory_id(items[index]) == id:
			return index
	return fallback if fallback < items.size() else -1

func _default_right(items: Array[InventoryEndpoint], left: int) -> int:
	for index: int in range(items.size()):
		if index != left and items[index].kind == InventoryEndpoint.Kind.STOP:
			return index
	for index: int in range(items.size()):
		if index != left:
			return index
	return -1

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

func _set_maximum() -> void:
	var source: InventoryTransferPanel = _left if _active_side == 0 else _right
	var target: InventoryTransferPanel = _right if _active_side == 0 else _left
	var maximum: float = InventoryTransferService.maximum(source.endpoint, target.endpoint, source.selected_stack)
	if maximum > 0:
		_quantity.value = maximum
#endregion

#region Transfer commands
func _transfer(source: InventoryTransferPanel, target: InventoryTransferPanel) -> void:
	var stack: InventoryStack = source.selected_stack
	var amount: float = _quantity.value
	var destination_label: String = target.endpoint.label if target.endpoint != null else ""
	var completes_trip: bool = InventoryTransferService.completes_passenger_trip(target.endpoint, stack)
	var error: String = InventoryTransferService.transfer(source.endpoint, target.endpoint, stack, amount)
	if not error.is_empty():
		_status.text = error
		_status.add_theme_color_override("font_color", Color("e9a48d"))
		return
	var quantity_text: String = InventoryPresentation.quantity(amount)
	if completes_trip:
		_status.text = "%s %s arrived at %s." % [quantity_text, str(stack.good_key).capitalize(), destination_label]
	else:
		_status.text = "Moved %s %s to %s." % [quantity_text, str(stack.good_key).capitalize(), destination_label]
	_status.add_theme_color_override("font_color", Color("c8dfb1"))
	_update_controls()
#endregion
