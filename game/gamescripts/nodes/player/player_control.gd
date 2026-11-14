## Owns the current vehicle and transfers camera, input and collision ownership.
@icon("res://assets/icons/nodes_3d/icon_player_control.svg")
class_name PlayerControl extends Node

signal vehicle_changed(vehicle: Node3D)
signal camera_changed(camera: Camera3D)

@export var avatar: PlayerAvatar

var _vehicle: Node3D
var _vehicle_camera: Camera3D
var _walking_collision_layer: int
var _walking_collision_mask: int


func current_train() -> Train3D:
	return _vehicle as Train3D


func current_road_vehicle() -> RoadVehicle3D:
	return _vehicle as RoadVehicle3D


func is_in_vehicle() -> bool:
	return is_instance_valid(_vehicle)


func active_camera() -> Camera3D:
	return _vehicle_camera if is_instance_valid(_vehicle_camera) else avatar.walking_camera


func interaction_anchor() -> Node3D:
	if is_instance_valid(current_road_vehicle()):
		return current_road_vehicle()
	return active_camera()


func enter_vehicle(vehicle: Node3D) -> bool:
	if vehicle is RoadVehicle3D:
		return enter_road_vehicle(vehicle)
	if vehicle is Vehicle3D:
		return enter_train(vehicle.train3d)
	return false


func enter_train(train: Train3D) -> bool:
	if not is_instance_valid(train) or not is_instance_valid(train.locomotive):
		return false
	return _board(train, train.get_cam())


func enter_road_vehicle(vehicle: RoadVehicle3D) -> bool:
	if not is_instance_valid(vehicle):
		return false
	return _board(vehicle, vehicle.camera)


func _board(vehicle: Node3D, camera: Camera3D) -> bool:
	if not vehicle.is_inside_tree() or vehicle.is_queued_for_deletion() \
			or not is_instance_valid(camera) or not camera.is_inside_tree():
		return false
	if _vehicle == vehicle:
		return true

	var previous := _vehicle
	if is_instance_valid(previous):
		_release_vehicle()
	else:
		var body := avatar.walking_body
		_walking_collision_layer = body.collision_layer
		_walking_collision_mask = body.collision_mask
		avatar.suspend_walking(self)
		body.collision_layer = 0
		body.collision_mask = 0
		body.velocity = Vector3.ZERO

	_vehicle = vehicle
	_vehicle_camera = camera
	vehicle.tree_exiting.connect(_on_vehicle_exiting)
	if vehicle is RoadVehicle3D:
		vehicle.set_player_driving(true)
	_activate_camera(camera)
	UiState.set_gameplay_mouse_mode(Input.MOUSE_MODE_CONFINED)
	_notify_vehicle_changed(previous)
	return true


func exit_vehicle() -> bool:
	if not is_instance_valid(_vehicle):
		return false
	var previous := _vehicle
	var exit_position := avatar.walking_position()
	if previous is RoadVehicle3D:
		exit_position = previous.global_position + previous.global_basis.x.normalized() * 3.0 + Vector3.UP * 0.5
	elif is_instance_valid(_vehicle_camera) and _vehicle_camera.is_inside_tree():
		exit_position = _vehicle_camera.global_position + Vector3(12, -1, 0)
	elif previous.is_inside_tree():
		exit_position = previous.global_position + Vector3(12, -1, 0)

	_release_vehicle()
	avatar.place_at(exit_position)
	_restore_walking()
	_activate_camera(avatar.walking_camera)
	UiState.set_gameplay_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_notify_vehicle_changed(previous)
	return true


func _on_vehicle_exiting() -> void:
	exit_vehicle()


func _release_vehicle() -> void:
	_vehicle.tree_exiting.disconnect(_on_vehicle_exiting)
	if _vehicle is RoadVehicle3D:
		_vehicle.set_player_driving(false)
	_vehicle = null
	_vehicle_camera = null


func _restore_walking() -> void:
	var body := avatar.walking_body
	body.collision_layer = _walking_collision_layer
	body.collision_mask = _walking_collision_mask
	avatar.resume_walking(self)


func _activate_camera(camera: Camera3D) -> void:
	camera.make_current()
	if GlobalState.player == avatar:
		GlobalState.active_cam = camera
	camera_changed.emit(camera)


func _notify_vehicle_changed(previous: Node3D) -> void:
	vehicle_changed.emit(_vehicle)
	# Existing train controls still subscribe to these compatibility events.
	if previous is RoadVehicle3D:
		SignalBus.player_exited_road_vehicle.emit()
	elif previous is Train3D:
		SignalBus.player_exited_train.emit()
	if _vehicle is RoadVehicle3D:
		SignalBus.player_entered_road_vehicle.emit(_vehicle)
	elif _vehicle is Train3D:
		SignalBus.player_entered_train.emit(_vehicle)


func _exit_tree() -> void:
	if is_instance_valid(_vehicle):
		var previous := _vehicle
		_release_vehicle()
		_restore_walking()
		_notify_vehicle_changed(previous)
