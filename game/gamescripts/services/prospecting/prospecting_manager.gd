## Provides geology queries and owns the survey records for the active map.
class_name ProspectingManager extends Node

const SURVEY_RADIUS: float = 2.0

@export var marker_scene: PackedScene

var _world: WorldMapScene
var _markers: Dictionary[int, SurveyMarker3D] = {}
var _next_marker_num: int = 1


func set_world(world: WorldMapScene) -> void:
	if _world == world:
		return
	_clear_markers()
	_world = world


## Vector2 carries world X and Z. Only the sign needs the surface height.
func ground_position(world_pos: Vector2) -> Vector3:
	if not world_pos.is_finite() or not is_instance_valid(_world) or not is_instance_valid(_world.terrain):
		return Vector3.INF
	var terrain: Terrain3DData = _world.terrain.data
	var position := Vector3(world_pos.x, 0.0, world_pos.y)
	if terrain == null or not terrain.has_regionp(position) or terrain.get_control_hole(position):
		return Vector3.INF
	position.y = terrain.get_height(position)
	return position if is_finite(position.y) else Vector3.INF


## Sample the geology beneath a world X/Z point without adding a survey record.
func get_traces_at_pos(world_pos: Vector2) -> Dictionary[String, float]:
	var position: Vector3 = ground_position(world_pos)
	if position.is_finite():
		return _world.sample_minerals_at(position)
	return {}


func readings_near(world_pos: Vector2) -> Dictionary[String, float]:
	var marker := _nearest_marker(world_pos)
	if marker != null:
		return marker.readings
	return {}


func get_marker(marker_num: int) -> SurveyMarker3D:
	var marker: Variant = _markers.get(marker_num)
	return marker if is_instance_valid(marker) and not marker.is_queued_for_deletion() else null


func survey(world_pos: Vector2) -> Dictionary[String, float]:
	var position: Vector3 = ground_position(world_pos)
	if not position.is_finite():
		return {}
	# A nearby sign keeps its original sample point and report.
	var marker := _nearest_marker(world_pos)
	if marker != null:
		return marker.readings
	if marker_scene == null:
		return {}
	var node: Node = marker_scene.instantiate()
	if not node is SurveyMarker3D:
		node.free()
		return {}
	marker = node
	marker.marker_num = _next_marker_num
	marker.readings = _world.sample_minerals_at(position)
	_markers[_next_marker_num] = marker
	_next_marker_num += 1
	_world.add_child(marker)
	marker.global_position = position
	return marker.readings


func _nearest_marker(world_pos: Vector2) -> SurveyMarker3D:
	var nearest: SurveyMarker3D
	var closest_distance: float = SURVEY_RADIUS * SURVEY_RADIUS
	for marker_num: int in _markers:
		var marker := get_marker(marker_num)
		if marker == null:
			continue
		var position: Vector3 = marker.global_position
		var distance: float = world_pos.distance_squared_to(Vector2(position.x, position.z))
		if distance <= closest_distance:
			nearest = marker
			closest_distance = distance
	return nearest


func _clear_markers() -> void:
	for marker: Variant in _markers.values():
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()
	_next_marker_num = 1


func _exit_tree() -> void:
	_clear_markers()
	_world = null
