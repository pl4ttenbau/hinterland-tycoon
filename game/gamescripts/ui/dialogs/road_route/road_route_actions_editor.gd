## Load and unload tab of the road route dialog: what the vehicle does when it
## stops at the route point selected on the Route points tab. Each action loads
## or unloads a set of goods; passenger actions also name the destination
## interchanges whose passengers it moves. Actions run in this order at the
## stop. Edits go straight into the dialog's draft; nothing is transferred
## until the vehicle actually drives the plan.
class_name RoadRouteActionsEditor extends VBoxContainer

## Rejected inputs, or "" once an action was added. The dialog shows these in
## the accent tone.
signal status_changed(message: String)

var _vehicle: RoadVehicle3D
var _stops: Dictionary
## The route point being edited, a point of the draft plan; null when none is
## selected. Only stop points can carry actions.
var _point: RoadRoutePoint

## Actions at the current point, in execution order.
@onready var _actions: ItemList = %Actions
## Load or unload, for the next action to add.
@onready var _kind: OptionButton = %ActionKind
## Multi-select: every good the next action applies to (item metadata: good key).
@onready var _goods: ItemList = %Goods
## Multi-select: destination interchanges for passengers (item metadata: number).
@onready var _passenger_targets: ItemList = %PassengerTargets


func _ready() -> void:
	%AddAction.pressed.connect(_add_action)
	%RemoveAction.pressed.connect(_remove_action)
	%MoveUp.pressed.connect(_move_action.bind(-1))
	%MoveDown.pressed.connect(_move_action.bind(1))


## Fills the choices once per dialog: every good in the catalog, and every
## interchange reachable through a known stop. The vehicle is needed to check
## new actions against its cargo category.
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


## Switches to another route point (null clears the tab). label is the point's
## readable name from the points editor.
func show_point(point: RoadRoutePoint, label: String = "") -> void:
	_point = point
	%ActionContext.text = "Actions at " + label if _point != null else "Select a physical stop on the Route points tab."
	_refresh_actions()


func _refresh_actions() -> void:
	_actions.clear()
	if _point != null:
		for action: RoadRouteAction in _point.actions:
			_actions.add_item(action.describe())


## Builds an action from the current choices and appends it to the selected
## stop, after RoadRouteAction.validate() accepts it (goods exist, fit the
## vehicle's capacity, passengers have a destination).
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


## Moves the selected action one place up (-1) or down (+1), which changes the
## order it runs in at the stop.
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
