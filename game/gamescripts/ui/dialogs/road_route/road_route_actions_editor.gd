## Edits transfer instructions belonging to the selected visit in the draft.
class_name RoadRouteActionsEditor extends VBoxContainer

signal status_changed(message: String)

var _vehicle: RoadVehicle3D
var _stops: Dictionary
var _point: RoadRoutePoint

@onready var _actions: ItemList = %Actions
@onready var _kind: OptionButton = %ActionKind
@onready var _goods: ItemList = %Goods
@onready var _passenger_targets: ItemList = %PassengerTargets


func edit(vehicle: RoadVehicle3D, stops: Dictionary) -> void:
	_vehicle = vehicle
	_stops = stops
	_goods.clear()
	for key: String in GameTypes.resource_types:
		var index: int = _goods.add_item(key.capitalize())
		_goods.set_item_metadata(index, StringName(key))
	_passenger_targets.clear()
	var destinations: Dictionary[int, InterchangeData] = RoadRouteAction.available_destinations(_stops)
	for id: int in destinations:
		var index: int = _passenger_targets.add_item(InventoryPresentation.interchange_label(destinations[id]))
		_passenger_targets.set_item_metadata(index, id)


func show_point(point: RoadRoutePoint, label: String = "") -> void:
	_point = point
	%ActionContext.text = "Actions at " + label if _point != null else "Select a physical stop on the Route points tab."
	_refresh_actions()


func _refresh_actions() -> void:
	_actions.clear()
	if _point != null:
		for action: RoadRouteAction in _point.actions:
			_actions.add_item(action.describe())


func _add_action() -> void:
	if not is_instance_valid(_vehicle):
		_reject_action("This vehicle is no longer available.")
		return
	if _point == null or _point.kind != RoadRoutePoint.Kind.STOP:
		_reject_action("Select a physical stop before adding a transfer action.")
		return
	var action := RoadRouteAction.new()
	action.kind = _kind.get_selected_id() as RoadRouteAction.Kind
	for item: int in _goods.get_selected_items():
		action.goods.append(_goods.get_item_metadata(item))
	for item: int in _passenger_targets.get_selected_items():
		action.passenger_interchange_targets.append(_passenger_targets.get_item_metadata(item))

	var error: String = action.validate(GameTypes.resource_types, _stops, _vehicle.vehicle_obj.veh_type.capacity)
	if not error.is_empty():
		_reject_action(error)
		return
	_point.actions.append(action)
	_refresh_actions()
	_actions.select(_actions.item_count - 1)
	_actions.ensure_current_is_visible()
	status_changed.emit("")


func _reject_action(message: String) -> void:
	Loggie.warn("Could not add road route action: %s" % message)
	status_changed.emit(message)


func _remove_action() -> void:
	var selected: PackedInt32Array = _actions.get_selected_items()
	if _point != null and not selected.is_empty():
		_point.actions.remove_at(selected[0])
		_refresh_actions()


func _move_action(direction: int) -> void:
	var selected: PackedInt32Array = _actions.get_selected_items()
	if _point == null or selected.is_empty():
		return
	var index: int = selected[0]
	var target: int = index + direction
	if target < 0 or target >= _point.actions.size():
		return
	var action: RoadRouteAction = _point.actions.pop_at(index)
	_point.actions.insert(target, action)
	_refresh_actions()
	_actions.select(target)
