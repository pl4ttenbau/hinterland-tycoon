@icon("res://assets/icons/nodes_3d/icon_player_avatar.svg")
class_name PlayerAvatar extends InventoryEntity3D

@export var walking_body: BasicFpsPlayer
@export var walking_camera: Camera3D
@export var control: PlayerControl

var _station_overlaps: Dictionary[RailStation3D, int] = {}
var _walking_suspensions: Array[Node] = []
var _walking_process_mode: Node.ProcessMode


func _enter_tree() -> void:
	GlobalState.player = self
	GlobalState.active_cam = walking_camera
	SignalBus.player_entered_station.connect(_on_station_entered)
	SignalBus.player_exited_station.connect(_on_station_exited)


func _exit_tree() -> void:
	super._exit_tree()
	SignalBus.player_entered_station.disconnect(_on_station_entered)
	SignalBus.player_exited_station.disconnect(_on_station_exited)
	_station_overlaps.clear()
	if GlobalState.player == self:
		GlobalState.player = null
		GlobalState.active_cam = null


func place_at(world_position: Vector3) -> void:
	walking_body.global_position = world_position
	walking_body.velocity = Vector3.ZERO


func walking_position() -> Vector3:
	return walking_body.global_position


func suspend_walking(owner: Node) -> void:
	if _walking_suspensions.has(owner):
		return
	if _walking_suspensions.is_empty():
		_walking_process_mode = walking_body.process_mode
	_walking_suspensions.append(owner)
	walking_body.process_mode = Node.PROCESS_MODE_DISABLED


func resume_walking(owner: Node) -> void:
	if not _walking_suspensions.has(owner):
		return
	_walking_suspensions.erase(owner)
	if _walking_suspensions.is_empty():
		walking_body.process_mode = _walking_process_mode


func current_station() -> RailStation3D:
	var closest: RailStation3D
	var closest_distance: float = INF
	for station: RailStation3D in _station_overlaps:
		if is_instance_valid(station) and station.is_inside_tree():
			var distance := station.global_position.distance_squared_to(walking_position())
			if distance < closest_distance:
				closest = station
				closest_distance = distance
	return closest


func _on_station_entered(station: RailStation3D) -> void:
	if is_instance_valid(station):
		_station_overlaps[station] = _station_overlaps.get(station, 0) + 1


func _on_station_exited(station: RailStation3D) -> void:
	var remaining: int = _station_overlaps.get(station, 0) - 1
	if remaining > 0:
		_station_overlaps[station] = remaining
	else:
		_station_overlaps.erase(station)
