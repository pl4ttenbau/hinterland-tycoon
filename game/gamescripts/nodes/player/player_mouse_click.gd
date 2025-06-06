@icon("res://assets/icons/icon_mouse_white.png")
class_name PlayerMouseClick extends Node

# Signals
signal player_input(event: InputEvent, event_position: Vector3)
signal player_clicked()

func _input(event: InputEvent) -> void:
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
	ray_query.collide_with_areas = true
	# shoot
	var ray_result: Dictionary = space.intersect_ray(ray_query)
	self.handle_ray(ray_result)
	
func handle_ray(ray_result: Dictionary):
	var collider: Node3D = ray_result.get("collider") as Node3D
	if collider:
		if collider is ClickableCollider:
			var c_ref: ClickRef = collider.get_click_ref()
			SignalBus.collider_click.emit(c_ref)
			Loggie.info("Click %s %d" % [c_ref.get_type_str(), c_ref.entity_num])
		elif collider is Terrain3D:
			Loggie.info("Click on terrain at %s" % ray_result.get("position"))
		else:
			SignalBus.unhandled_collider_click.emit(collider)
			var node_path = collider.get_path()
			Loggie.info("Unhandled Click: %s at %s" %[collider.name, node_path])

func get_camera() -> Camera3D:
	var cam: Camera3D = GlobalState.player.cam
	if ! cam:
		Loggie.error("Camera not found")
	return cam
