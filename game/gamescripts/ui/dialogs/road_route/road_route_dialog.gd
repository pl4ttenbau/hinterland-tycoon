## Edit a private copy. Save and Start are the only operations that publish it.
class_name RoadRouteDialog extends ModalGameDialog

const SCENE_PATH = "res://scenes/ui/dialogs/road_route/road_route_dialog.tscn"

var vehicle: RoadVehicle3D
var plan: RoadRoutePlan

@onready var _points_editor: RoadRoutePointsEditor = %"Route points"
@onready var _actions_editor: RoadRouteActionsEditor = %"Load and unload"
@onready var _status: Label = %Status


static func create(source_vehicle: RoadVehicle3D) -> RoadRouteDialog:
	var scene := load(SCENE_PATH) as PackedScene
	var dialog := scene.instantiate() as RoadRouteDialog
	dialog.vehicle = source_vehicle
	return dialog


func _ready() -> void:
	if not is_instance_valid(vehicle):
		_show_status("This vehicle is no longer available.")
		%OkButton.disabled = true
		%StartButton.disabled = true
		return
	plan = vehicle.route_plan.duplicate(true)
	var markers: RoadMarkerStore = Managers.roads.markers if is_instance_valid(Managers.roads) else null
	var stops: Dictionary = _all_stops()
	_show_status("%s. Start the plan, then leave the vehicle for automatic driving." % vehicle.plan_execution.status)
	_actions_editor.edit(vehicle, stops)
	_points_editor.edit(plan, markers, stops, GlobalState.road_depots)


func _all_stops() -> Dictionary:
	return Managers.interchanges.stops_by_num if is_instance_valid(Managers.interchanges) else {}


func _on_point_selected(index: int) -> void:
	if index < 0:
		_actions_editor.show_point(null)
		return
	var point: RoadRoutePoint = plan.points[index]
	_actions_editor.show_point(point, "point %d · %s" % [index + 1, _points_editor.point_label(point)])


func _show_status(message: String) -> void:
	_status.text = message


func _save() -> void:
	if not is_instance_valid(vehicle):
		_show_status("This vehicle is no longer available.")
		return
	if not is_instance_valid(Managers.roads):
		_show_status("Road network is unavailable.")
		return

	# Rebuild against the live roads when saving the edited plan.
	var network := RoadPathfinder.new()
	var vehicle_type: VehicleTypeData = vehicle.vehicle_obj.veh_type
	network.build(Managers.roads.storage.get_all(), vehicle_type.usable_infr.subtype)
	var error: String = plan.validate(network, Managers.roads.storage, _all_stops(), GlobalState.road_depots,
		GameTypes.resource_types, vehicle_type.capacity, Managers.roads.markers)
	_show_status(error)
	if error.is_empty():
		vehicle.plan_execution.stop(vehicle)
		vehicle.route_plan = plan
		close_all()


func _start() -> void:
	if not is_instance_valid(vehicle):
		_show_status("This vehicle is no longer available.")
		return
	var previous: RoadRoutePlan = vehicle.route_plan
	vehicle.route_plan = plan
	if vehicle.plan_execution.start(vehicle):
		close_all()
	else:
		vehicle.route_plan = previous
		_show_status(vehicle.plan_execution.status)
