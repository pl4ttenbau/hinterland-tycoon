@icon("res://assets/icons/icon_mouse_white.png")
class_name PlayerMouseClick extends Node

# Signals
@warning_ignore("unused_signal")
signal player_input(event: InputEvent, event_position: Vector3)

func _input(event: InputEvent) -> void:
	# Dialog blocking? dont continue further
	if UiState.current_diag != null:
		Loggie.debug("prevented World click with open dialog")
		return
	# cast ray into world space
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		# only delegate events at end of click
		if !mouse_event.pressed:
			self.cast_ray(mouse_event.position)
			SignalBus.mouse_click.emit(mouse_event)
			
func cast_ray(screen_pos: Vector2):
	var cam_pos: Vector3 = self.get_camera().project_ray_origin(screen_pos)
	var to = cam_pos + get_camera().project_ray_normal(screen_pos) * 300
	var space = get_camera().get_world_3d().direct_space_state
	# create ray
	var ray_query = PhysicsRayQueryParameters3D.create(cam_pos, to)
	ray_query.collide_with_areas = false
	# shoot
	var ray_result: Dictionary = space.intersect_ray(ray_query)
	self.handle_ray(ray_result)
	
func handle_ray(ray_result: Dictionary):
	var collider: Node3D = ray_result.get("collider") as Node3D
	if !collider: return
	var is_click_on_entity: bool = $EntityClickHandler.handle_click(collider)
	if is_click_on_entity:
		get_viewport().set_input_as_handled()
		return
	if ! is_click_on_entity:
		var is_click_on_terrain: bool = $TerrainClickHandler.handle_click(collider, ray_result)
		if is_click_on_terrain: return
	else:
		SignalBus.unhandled_collider_click.emit(collider)
		var node_path = collider.get_path()
		Loggie.info("Unhandled Click: %s at %s" %[collider.name, node_path])

func get_camera() -> Camera3D:
	var cam: Camera3D = GlobalState.player.cam
	if ! cam:
		Loggie.error("Camera not found")
	return cam

func _get_configuration_warnings() -> PackedStringArray:
	var err_msgs: PackedStringArray = []
	if !$EntityClickHandler:
		err_msgs.append("EntityClickHandler (BaseEntityClickHandler) child node missing")
	if !$TerrainClickHandler:
		err_msgs.append("TerrainClickHandler (TerrainClickHandler) child node missing")
	return []
