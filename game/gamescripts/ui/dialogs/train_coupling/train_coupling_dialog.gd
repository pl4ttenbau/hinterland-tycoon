## The only gameplay interface for coupling or splitting a consist.
class_name TrainCouplingDialog extends ModalGameDialog

const BASE_SCENE := "res://scenes/ui/dialogs/default_dialog.tscn"

class NearbyPanel:
	var count: Label
	var list: ItemList
	var pair: Label
	var button: Button
	var vehicles: Array[Vehicle3D] = []
	var facing: Vehicle3D
	var connection: TrainCoupling.Connection

var _selected: Vehicle3D
var _current_list: ItemList
var _current_heading: Label
var _status: Label
var _front: NearbyPanel
var _rear: NearbyPanel
var _split_above: Button
var _split_below: Button
var _confirmation: HBoxContainer
var _summary: Label
var _preview_summary: String
var _confirm: Button
var _pending_join: TrainCoupling.Connection
var _ahead: Vehicle3D
var _behind: Vehicle3D
var _error: Label
var _displayed: Array[Vehicle3D] = []
var _displayed_cut: int = -1

static func create(vehicle: Vehicle3D) -> TrainCouplingDialog:
	var scene: PackedScene = load(BASE_SCENE)
	var frame: Control = scene.instantiate()
	frame.set_script(TrainCouplingDialog)
	var dialog := frame as TrainCouplingDialog
	dialog._selected = vehicle
	return dialog

func _ready() -> void:
	dialog_key = "TrainCouplingDialog"
	title_text = "Coupling"
	_build_content()
	_refresh()
	_current_list.grab_focus()
	var refresh_timer := Timer.new()
	refresh_timer.wait_time = 0.25
	refresh_timer.autostart = true
	refresh_timer.timeout.connect(_refresh)
	add_child(refresh_timer)

func _build_content() -> void:
	# Leave room for both consist columns. The base scene centers the panel as it grows.
	$OuterPanel.custom_minimum_size = Vector2(704, 517)
	var content: VBoxContainer = %Content
	_status = _label(content)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	content.add_child(columns)
	var current := VBoxContainer.new()
	current.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current.size_flags_stretch_ratio = 1.25
	columns.add_child(current)
	_current_heading = _label(current)
	_current_list = _vehicle_list(current, 232)
	_current_list.item_selected.connect(_select_vehicle)
	var nearby := VBoxContainer.new()
	nearby.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nearby.add_theme_constant_override("separation", 8)
	columns.add_child(nearby)
	_front = _build_nearby_panel(nearby, "In Front", true)
	nearby.add_child(HSeparator.new())
	_rear = _build_nearby_panel(nearby, "Behind", false)
	content.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	content.add_child(actions)
	_split_above = _button(actions, "Uncouple above", _preview_split.bind(true))
	_split_below = _button(actions, "Uncouple below", _preview_split.bind(false))
	_confirmation = HBoxContainer.new()
	content.add_child(_confirmation)
	_summary = _label(_confirmation)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(_confirmation, "Cancel", _cancel_preview)
	_confirm = _button(_confirmation, "Confirm", _commit)
	_confirm.theme_type_variation = &"PrimaryButton"
	_error = _label(content)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.hide()

func _build_nearby_panel(parent: VBoxContainer, heading: String, at_front: bool) -> NearbyPanel:
	var panel := NearbyPanel.new()
	panel.count = _label(parent, heading)
	panel.list = _vehicle_list(parent, 80)
	panel.list.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.list.focus_mode = Control.FOCUS_NONE
	panel.pair = _label(parent)
	panel.pair.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.button = _button(parent, "Couple at front" if at_front else "Couple at rear", _preview_join.bind(at_front))
	panel.button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return panel

func _label(parent: Container, value: String = "") -> Label:
	var label := Label.new()
	label.text = value
	parent.add_child(label)
	return label

func _button(parent: Container, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _vehicle_list(parent: VBoxContainer, height: float) -> ItemList:
	var list := ItemList.new()
	list.custom_minimum_size.y = height
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(list)
	return list

func _refresh() -> void:
	if _closing:
		return
	if not is_instance_valid(_selected) or not TrainCoupling.available(_selected.train3d):
		close_all()
		return
	var train: Train3D = _selected.train3d
	_status.text = "Train %d  ·  %s" % [train.num, "Stopped" if train.movement.is_parked() else "Bring the train to a stop"]
	var cut: int = _behind.num_in_train if is_instance_valid(_behind) and _behind.train3d == train else -1
	if _displayed != train.vehicles or _displayed_cut != cut:
		_render_consist(train, cut)
	_refresh_nearby(train, _front, true)
	_refresh_nearby(train, _rear, false)
	var selected_index: int = _selected.num_in_train
	_split_above.disabled = selected_index == 0 or not train.movement.is_parked()
	_split_below.disabled = selected_index == train.count() - 1 or not train.movement.is_parked()
	_confirmation.visible = _pending_join != null or is_instance_valid(_ahead)
	if _confirmation.visible:
		var problem: String
		if _pending_join != null:
			var plan: TrainCoupling.JoinPlan = TrainCoupling.plan_join(train, _pending_join.at_front, _pending_join)
			problem = plan.error
			if problem.is_empty():
				_preview_summary = _join_summary(plan)
		else:
			problem = TrainCoupling.split_error(train, _ahead, _behind)
		_summary.text = _preview_summary if problem.is_empty() else _preview_summary + "\n" + problem
		_confirm.disabled = not problem.is_empty()

func _render_consist(train: Train3D, cut: int) -> void:
	_displayed = train.vehicles.duplicate()
	_displayed_cut = cut
	_current_heading.text = "Selected consist  ·  %s" % _count(train.count())
	_current_list.clear()
	for index: int in range(train.count()):
		if index == cut:
			var divider: int = _current_list.add_item("──────── Split here ────────")
			_current_list.set_item_selectable(divider, false)
		var vehicle: Vehicle3D = train.vehicles[index]
		var end: String = ""
		if train.count() == 1:
			end = "Front / rear"
		elif index == 0:
			end = "Front"
		elif index == train.count() - 1:
			end = "Rear"
		var row: int = _add_vehicle_row(_current_list, vehicle, end)
		if vehicle == _selected:
			_current_list.select(row)
	_current_list.ensure_current_is_visible.call_deferred()

func _refresh_nearby(train: Train3D, panel: NearbyPanel, at_front: bool) -> void:
	var plan: TrainCoupling.JoinPlan = TrainCoupling.plan_join(train, at_front)
	var connection: TrainCoupling.Connection = plan.connection
	panel.connection = connection
	var heading: String = "In Front" if at_front else "Behind"
	panel.list.visible = connection != null
	panel.pair.visible = connection != null
	panel.button.visible = connection != null
	if connection == null:
		panel.count.text = heading + "  ·  None in range"
		panel.vehicles.clear()
		panel.facing = null
		return
	var other: Train3D = connection.other
	panel.count.text = heading + "  ·  " + _count(other.count())
	if panel.vehicles != other.vehicles or panel.facing != connection.facing_end:
		panel.vehicles = other.vehicles.duplicate()
		panel.facing = connection.facing_end
		panel.list.clear()
		var facing_first: bool = panel.facing == other.vehicles.front()
		for index: int in range(other.count()):
			var vehicle: Vehicle3D = other.vehicles[index if facing_first else -index - 1]
			var row: int = _add_vehicle_row(panel.list, vehicle, "Facing end" if index == 0 else "")
			panel.list.set_item_selectable(row, false)
	panel.pair.text = _pair(connection.own_end, connection.facing_end)
	var problem: String = plan.error
	panel.button.disabled = not problem.is_empty()
	panel.pair.tooltip_text = problem
	if not problem.is_empty():
		panel.pair.text += "\n" + problem

func _add_vehicle_row(list: ItemList, vehicle: Vehicle3D, end: String) -> int:
	var name_text: String = _vehicle_name(vehicle)
	var row: int = list.add_item(name_text if end.is_empty() else name_text + "  ·  " + end)
	list.set_item_metadata(row, vehicle)
	return row

func _vehicle_name(vehicle: Vehicle3D) -> String:
	return "%s #%d" % [vehicle.vehicle_obj.veh_type.display_name, vehicle.vehicle_obj.num]

func _pair(first: Vehicle3D, second: Vehicle3D) -> String:
	return "%s ↔ %s" % [_vehicle_name(first), _vehicle_name(second)]

func _count(count: int) -> String:
	return "1 vehicle" if count == 1 else "%d vehicles" % count

func _select_vehicle(row: int) -> void:
	_selected = _current_list.get_item_metadata(row) as Vehicle3D
	_cancel_preview()

func _cancel_preview() -> void:
	_pending_join = null
	_ahead = null
	_behind = null
	_error.hide()
	_refresh()

func _preview_split(above: bool) -> void:
	var train: Train3D = _selected.train3d
	var cut: int = _selected.num_in_train + (0 if above else 1)
	if cut <= 0 or cut >= train.count():
		return
	_pending_join = null
	_ahead = train.vehicles[cut - 1]
	_behind = train.vehicles[cut]
	_preview_summary = "%s\n%s + %s" % [_pair(_ahead, _behind), _count(cut), _count(train.count() - cut)]
	_confirm.text = "Confirm split"
	_error.hide()
	_refresh()

func _preview_join(at_front: bool) -> void:
	var train: Train3D = _selected.train3d
	var panel: NearbyPanel = _front if at_front else _rear
	if panel.connection == null:
		return
	var plan: TrainCoupling.JoinPlan = TrainCoupling.plan_join(train, at_front, panel.connection)
	if not plan.error.is_empty():
		_refresh()
		return
	_pending_join = plan.connection
	_ahead = null
	_behind = null
	_preview_summary = _join_summary(plan)
	_confirm.text = "Confirm coupling"
	_error.hide()
	_refresh()

func _join_summary(plan: TrainCoupling.JoinPlan) -> String:
	var connection: TrainCoupling.Connection = plan.connection
	return "%s · %s\nOne consist · %s" % ["Front" if connection.at_front else "Rear",
		_pair(connection.own_end, connection.facing_end), _count(plan.ordered.size())]

func _commit() -> void:
	if _closing or not is_instance_valid(_selected):
		return
	var train: Train3D = _selected.train3d
	var problem: String = TrainCoupling.join(train, _pending_join) if _pending_join != null \
		else TrainCoupling.split(train, _ahead, _behind)
	_cancel_preview()
	if not problem.is_empty():
		_error.text = problem
		_error.show()
