## Edit a private copy; only a validated Save replaces the vehicle's itinerary.
class_name RoadRouteDialog extends ModalGameDialog

var vehicle: RoadVehicle3D
var plan: RoadRoutePlan
var network := RoadPathfinder.new()
var _points: ItemList
var _kind: OptionButton
var _targets: OptionButton
var _choices: Array[RoadRoutePoint] = []
var _actions: ItemList
var _action_kind: OptionButton
var _goods: ItemList
var _passenger_targets: ItemList
var _status: Label
var _action_context: Label

static func create(source_vehicle: RoadVehicle3D) -> RoadRouteDialog:
	var frame: Control = load("res://scenes/ui/dialogs/default_dialog.tscn").instantiate()
	frame.set_script(load("res://game/gamescripts/ui/dialogs/road_route/road_route_dialog.gd"))
	var dialog := frame as RoadRouteDialog
	dialog.vehicle = source_vehicle
	return dialog

func _ready() -> void:
	dialog_key = "RoadRouteDialog"
	title_text = "Road vehicle route"
	plan = vehicle.route_plan.duplicate(true)
	network.build(Managers.roads.storage.get_all(), vehicle.vehicle_obj.veh_type.usable_infr.subtype)
	_build_content()
	_build_footer()
	_fill_point_choices()
	_refresh_points()

func _build_content() -> void:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(680, 360)
	get_node("OuterPanel/OuterMargin/OuterVLayout/Container").add_child(tabs)
	var points := VBoxContainer.new()
	points.name = "Route points"
	tabs.add_child(points)
	_build_points_tab(points)
	var actions := VBoxContainer.new()
	actions.name = "Load and unload"
	tabs.add_child(actions)
	_build_actions_tab(actions)

func _build_points_tab(content: VBoxContainer) -> void:
	_kind = OptionButton.new()
	_kind.add_item("Road marker", RoadRoutePoint.Kind.MARKER)
	_kind.add_item("Physical stop", RoadRoutePoint.Kind.STOP)
	_kind.add_item("Road depot", RoadRoutePoint.Kind.DEPOT)
	_kind.item_selected.connect(func(_index: int): _fill_point_choices())
	content.add_child(_kind)
	_targets = OptionButton.new()
	_targets.get_popup().allow_search = true
	content.add_child(_targets)
	_add_button(content, "Add point", _add_point)
	_points = ItemList.new()
	_points.custom_minimum_size.y = 165
	_points.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_points.item_selected.connect(func(_index: int): _refresh_actions())
	content.add_child(_points)
	var controls := HBoxContainer.new()
	content.add_child(controls)
	_add_button(controls, "Move up", func(): _move_point(-1))
	_add_button(controls, "Move down", func(): _move_point(1))
	_add_button(controls, "Remove point", _remove_point)

func _build_actions_tab(content: VBoxContainer) -> void:
	var help := Label.new()
	_action_context = help
	help.text = "Select a route point on the first tab. Transfers require a physical stop."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)
	var policy := Label.new()
	policy.text = "Actions run once, in order, moving as much as stock and capacity allow. Passengers unloaded at their destination finish their trip."
	policy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	policy.theme_type_variation = &"MutedLabel"
	content.add_child(policy)
	_actions = ItemList.new()
	_actions.custom_minimum_size.y = 75
	content.add_child(_actions)
	_action_kind = OptionButton.new()
	_action_kind.add_item("Load")
	_action_kind.add_item("Unload")
	content.add_child(_action_kind)
	var selectors := HBoxContainer.new()
	content.add_child(selectors)
	_goods = _add_selector(selectors, "Goods (select one or more)")
	for key: String in GameTypes.resource_types:
		_goods.add_item(key.capitalize())
		_goods.set_item_metadata(_goods.item_count - 1, StringName(key))
	_passenger_targets = _add_selector(selectors, "Passenger destination interchanges")
	var destinations: Dictionary[int, InterchangeData] = RoadRouteAction.available_destinations(_all_stops())
	for id: int in destinations:
		_passenger_targets.add_item(InventoryPresentation.interchange_label(destinations[id]))
		_passenger_targets.set_item_metadata(_passenger_targets.item_count - 1, id)
	var buttons := HBoxContainer.new()
	content.add_child(buttons)
	_add_button(buttons, "Add action", _add_action)
	_add_button(buttons, "Remove action", _remove_action)
	_add_button(buttons, "Up", func(): _move_action(-1))
	_add_button(buttons, "Down", func(): _move_action(1))

func _add_selector(parent: Control, caption: String) -> ItemList:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var label := Label.new()
	label.text = caption
	column.add_child(label)
	var list := ItemList.new()
	list.select_mode = ItemList.SELECT_MULTI
	list.custom_minimum_size = Vector2(310, 100)
	column.add_child(list)
	return list

func _build_footer() -> void:
	var box: Node = get_node("OuterPanel/OuterMargin/OuterVLayout")
	_status = Label.new()
	_status.text = "%s. Start plan, then leave the vehicle for automatic driving." % vehicle.plan_execution.status
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	var save: Button = get_node("%OkButton")
	save.text = "Save plan"
	save.pressed.connect(_save)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	save.reparent(actions)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button(actions, "Start plan", _start)
	_add_button(actions, "Cancel", close_all)

func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)

func _all_stops() -> Dictionary:
	return Managers.interchanges.stops_by_num if is_instance_valid(Managers.interchanges) else {}

#region Point selection
func _fill_point_choices() -> void:
	_targets.clear()
	_choices.clear()
	match _kind.get_selected_id():
		RoadRoutePoint.Kind.MARKER:
			for marker: RoadMarkerData in Managers.roads.markers.markers:
				_offer_reference(RoadRoutePoint.Kind.MARKER, marker.num, "%s · %d" % [marker.marker_name, marker.num])
			if _choices.is_empty():
				_status.text = "No markers yet. On foot, open the circular menu and choose Place road marker while standing on a road."
		RoadRoutePoint.Kind.STOP:
			for id: int in _all_stops():
				var stop: RoadStationData = _all_stops()[id] as RoadStationData
				if stop != null:
					_offer_reference(RoadRoutePoint.Kind.STOP, id, "%s · stop %d" % [stop.get_display_name(), id])
		RoadRoutePoint.Kind.DEPOT:
			for depot: RoadDepotData in GlobalState.road_depots:
				_offer_reference(RoadRoutePoint.Kind.DEPOT, depot.num, "%s · depot %d" % [depot.depot_name, depot.num])

func _offer_reference(kind: RoadRoutePoint.Kind, id: int, label: String) -> void:
	var point := RoadRoutePoint.new()
	point.kind = kind
	point.target_num = id
	_offer_point(point, label)

func _offer_point(point: RoadRoutePoint, label: String) -> void:
	_choices.append(point)
	_targets.add_item(label)

func _add_point() -> void:
	if _targets.selected >= 0:
		plan.points.append(_choices[_targets.selected].duplicate(true))
		_refresh_points(plan.points.size() - 1)

func _selected_point() -> int:
	var selected: PackedInt32Array = _points.get_selected_items()
	return selected[0] if not selected.is_empty() else -1

func _move_point(direction: int) -> void:
	var index: int = _selected_point()
	var target: int = index + direction
	if index < 0 or target < 0 or target >= plan.points.size():
		return
	var point: RoadRoutePoint = plan.points.pop_at(index)
	plan.points.insert(target, point)
	_refresh_points(target)

func _remove_point() -> void:
	var index: int = _selected_point()
	if index >= 0:
		plan.points.remove_at(index)
		_refresh_points(mini(index, plan.points.size() - 1))

func _point_label(point: RoadRoutePoint) -> String:
	if point.kind == RoadRoutePoint.Kind.MARKER:
		var marker: RoadMarkerData = Managers.roads.markers.get_by_num(point.target_num)
		if marker != null:
			return "%s · marker %d" % [marker.marker_name, marker.num]
	return point.describe()

func _refresh_points(selected: int = 0) -> void:
	_points.clear()
	for index: int in range(plan.points.size()):
		_points.add_item("%d. %s" % [index + 1, _point_label(plan.points[index])])
	if selected >= 0 and selected < plan.points.size():
		_points.select(selected)
	_refresh_actions()
#endregion

#region Action editing and validation
func _refresh_actions() -> void:
	_actions.clear()
	var index: int = _selected_point()
	_action_context.text = "Select a route point on the first tab. Transfers require a physical stop."
	if index >= 0:
		_action_context.text = "Actions at point %d: %s" % [index + 1, _point_label(plan.points[index])]
		for action: RoadRouteAction in plan.points[index].actions:
			_actions.add_item(action.describe())

func _add_action() -> void:
	if not is_instance_valid(vehicle):
		_status.text = "This vehicle is no longer available."
		return
	var index: int = _selected_point()
	if index < 0 or plan.points[index].kind != RoadRoutePoint.Kind.STOP:
		_status.text = "Select a physical stop before adding a transfer action."
		return
	var action := RoadRouteAction.new()
	action.kind = _action_kind.selected as RoadRouteAction.Kind
	for item: int in _goods.get_selected_items():
		action.goods.append(_goods.get_item_metadata(item))
	for item: int in _passenger_targets.get_selected_items():
		action.passenger_interchange_targets.append(_passenger_targets.get_item_metadata(item))
	_status.text = action.validate(GameTypes.resource_types, _all_stops(), vehicle.vehicle_obj.veh_type.capacity)
	if _status.text.is_empty():
		plan.points[index].actions.append(action)
		_refresh_actions()

func _remove_action() -> void:
	var index: int = _selected_point()
	var selected: PackedInt32Array = _actions.get_selected_items()
	if index >= 0 and not selected.is_empty():
		plan.points[index].actions.remove_at(selected[0])
		_refresh_actions()

func _move_action(direction: int) -> void:
	var point: int = _selected_point()
	var selected: PackedInt32Array = _actions.get_selected_items()
	if point < 0 or selected.is_empty():
		return
	var index: int = selected[0]
	var target: int = index + direction
	if target < 0 or target >= plan.points[point].actions.size():
		return
	var action: RoadRouteAction = plan.points[point].actions.pop_at(index)
	plan.points[point].actions.insert(target, action)
	_refresh_actions()
	_actions.select(target)

func _save() -> void:
	if not is_instance_valid(vehicle):
		_status.text = "This vehicle is no longer available."
		return
	_status.text = plan.validate(network, Managers.roads.storage, _all_stops(), GlobalState.road_depots, GameTypes.resource_types, vehicle.vehicle_obj.veh_type.capacity, Managers.roads.markers)
	if _status.text.is_empty():
		vehicle.plan_execution.stop(vehicle)
		vehicle.route_plan = plan
		close_all()

func _start() -> void:
	if not is_instance_valid(vehicle):
		return
	var previous: RoadRoutePlan = vehicle.route_plan
	vehicle.route_plan = plan
	if vehicle.plan_execution.start(vehicle):
		close_all()
	else:
		vehicle.route_plan = previous
		_status.text = vehicle.plan_execution.status
#endregion
