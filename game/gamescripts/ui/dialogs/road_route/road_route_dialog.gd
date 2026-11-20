## Edits a road vehicle's route plan: which places it visits, in order (Route
## points tab), and what it loads or unloads at each stop (Load and unload tab).
##
## The dialog works on a draft, a deep copy of the vehicle's plan. Both editors
## change that draft directly; the vehicle's own plan stays untouched until the
## player presses Save or Start. Cancel or Escape simply drops the draft.
## - Save: validates the draft and makes it the vehicle's plan. A plan that was
##   running is stopped, because the executor drives a frozen copy of the old plan.
## - Start: makes the draft the vehicle's plan and starts driving it. The executor
##   validates it and freezes its own copy, so later edits never change a segment
##   that is already being driven.
class_name RoadRouteDialog extends ModalGameDialog

const SCENE_PATH = "res://scenes/ui/dialogs/road_route/road_route_dialog.tscn"

var vehicle: RoadVehicle3D
## The draft being edited. Shared with both editors, which mutate it in place.
var plan: RoadRoutePlan

@onready var _points_editor: RoadRoutePointsEditor = %"Route points"
@onready var _actions_editor: RoadRouteActionsEditor = %"Load and unload"


static func create(source_vehicle: RoadVehicle3D) -> RoadRouteDialog:
	var scene := load(SCENE_PATH) as PackedScene
	var dialog := scene.instantiate() as RoadRouteDialog
	dialog.vehicle = source_vehicle
	return dialog


func _ready() -> void:
	# 1. Wiring.
	_connect_signals()
	# 2. Guard: the vehicle may be gone by the time the dialog opens. Keep the
	#    dialog open with the reason; only Cancel remains usable.
	if not is_instance_valid(vehicle):
		show_status("This vehicle is no longer available.", StatusTone.ERROR)
		%OkButton.disabled = true
		%StartButton.disabled = true
		return
	# 3. Content: copy the plan into the draft and hand the draft to both editors.
	#    Markers may be missing on maps without a road network; the points editor
	#    then just offers no marker targets.
	plan = vehicle.route_plan.duplicate(true)
	var markers: RoadMarkerStore = Managers.roads.markers if is_instance_valid(Managers.roads) else null
	var stops: Dictionary = _all_stops()
	# Open with the execution state ("Not started", "Stopped", …) as a reminder
	# that a saved plan only drives once it is started.
	show_status("%s. Start the plan, then leave the vehicle for automatic driving." % vehicle.plan_execution.status)
	_actions_editor.edit(vehicle, stops)
	# Last: editing the points selects the first one, which already reaches the
	# actions editor through point_selected.
	_points_editor.edit(plan, markers, stops, GlobalState.road_depots)


func _connect_signals() -> void:
	# The selected route point decides which stop the actions editor works on.
	_points_editor.point_selected.connect(_on_point_selected)
	# Points editor messages are guidance (e.g. "No markers yet"); actions editor
	# messages are rejected inputs, so they stand out in the accent tone.
	_points_editor.status_changed.connect(show_status)
	_actions_editor.status_changed.connect(show_status.bind(StatusTone.ACCENT))
	%OkButton.pressed.connect(_save)
	%StartButton.pressed.connect(_start)


## Every stop by number, rail and road alike. The editors pick out the road stops.
func _all_stops() -> Dictionary:
	return Managers.interchanges.stops_by_num if is_instance_valid(Managers.interchanges) else {}


## index is -1 when the list has no selection (e.g. after removing the last point).
func _on_point_selected(index: int) -> void:
	if index < 0:
		_actions_editor.show_point(null)
		return
	var point: RoadRoutePoint = plan.points[index]
	_actions_editor.show_point(point, "point %d · %s" % [index + 1, _points_editor.point_label(point)])


## Publishes the draft as the vehicle's plan without starting it.
func _save() -> void:
	if not is_instance_valid(vehicle):
		show_status("This vehicle is no longer available.", StatusTone.ERROR)
		return
	if not is_instance_valid(Managers.roads):
		show_status("Road network is unavailable.", StatusTone.ERROR)
		return

	# Validate against the roads as they are now, not as they were when the
	# dialog opened, and only roads this vehicle type may use.
	var network := RoadPathfinder.new()
	var vehicle_type: VehicleTypeData = vehicle.vehicle_obj.veh_type
	network.build(Managers.roads.storage.get_all(), vehicle_type.usable_infr.subtype)
	var error: String = plan.validate(network, Managers.roads.storage, _all_stops(), GlobalState.road_depots,
		GameTypes.resource_types, vehicle_type.capacity, Managers.roads.markers)
	# An empty error also clears an earlier message.
	show_status(error, StatusTone.ERROR)
	if error.is_empty():
		# A running plan drives a frozen copy of the old plan; stop it so the
		# vehicle never keeps driving something the player just replaced.
		vehicle.plan_execution.stop(vehicle)
		vehicle.route_plan = plan
		close_all()


## Publishes the draft and starts driving it.
func _start() -> void:
	if not is_instance_valid(vehicle):
		show_status("This vehicle is no longer available.", StatusTone.ERROR)
		return
	# The executor starts whatever vehicle.route_plan holds, so swap the draft in,
	# and swap the old plan back if it refuses (invalid plan, no road network…).
	var previous: RoadRoutePlan = vehicle.route_plan
	vehicle.route_plan = plan
	if vehicle.plan_execution.start(vehicle):
		close_all()
	else:
		vehicle.route_plan = previous
		# The executor explains why in its status.
		show_status(vehicle.plan_execution.status, StatusTone.ERROR)
