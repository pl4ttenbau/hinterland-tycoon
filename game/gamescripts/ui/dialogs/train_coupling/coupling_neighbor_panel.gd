## The nearest consist at one end of the selected train, and the button to join it.
class_name CouplingNeighborPanel extends VBoxContainer

signal couple_requested(at_front: bool)

@export var at_front: bool = true

## The connection shown by the last `show_plan`; null when nothing is in range.
var connection: TrainCoupling.Connection
var _vehicles: Array[RailVehicle3D] = []
var _facing: RailVehicle3D

@onready var heading: Label = %Heading
@onready var list: ItemList = %Vehicles
@onready var pair: Label = %Pair
@onready var button: Button = %CoupleButton

func _ready() -> void:
	button.pressed.connect(_on_couple_button_pressed)
	heading.text = _title()
	button.text = "Couple at front" if at_front else "Couple at rear"

func show_plan(plan: TrainCoupling.JoinPlan) -> void:
	connection = plan.connection
	list.visible = connection != null
	pair.visible = connection != null
	button.visible = connection != null
	if connection == null:
		heading.text = _title() + "  ·  None in range"
		_vehicles.clear()
		_facing = null
		return
	var other: Train3D = connection.other
	heading.text = _title() + "  ·  " + TrainCouplingText.count(other.count())
	if _vehicles != other.vehicles or _facing != connection.facing_end:
		_render_other(other)
	pair.text = TrainCouplingText.pair(connection.own_end, connection.facing_end)
	button.disabled = not plan.error.is_empty()
	pair.tooltip_text = plan.error
	if not plan.error.is_empty():
		pair.text += "\n" + plan.error

## Lists the other consist starting at the end that faces this train.
func _render_other(other: Train3D) -> void:
	_vehicles = other.vehicles.duplicate()
	_facing = connection.facing_end
	list.clear()
	var facing_first: bool = _facing == other.vehicles.front()
	for index: int in range(other.count()):
		var vehicle: RailVehicle3D = other.vehicles[index if facing_first else -index - 1]
		var row: int = TrainCouplingText.add_vehicle_row(list, vehicle, "Facing end" if index == 0 else "")
		list.set_item_selectable(row, false)

func _title() -> String:
	return "In Front" if at_front else "Behind"

func _on_couple_button_pressed() -> void:
	couple_requested.emit(at_front)
