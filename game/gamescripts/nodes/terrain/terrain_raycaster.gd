class_name TerrainRaycaster extends Node

func shoot_ray(world_xz: Vector2) -> TerrainRaycastResult:
	var top_pos: Vector3 = Vector3(world_xz.x, 50, world_xz.y)
	var btm_pos: Vector3 = Vector3(world_xz.x, -10, world_xz.y)
	var space = get_tree().get_world_3d().direct_space_state
	# create ray
	var ray_query = PhysicsRayQueryParameters3D.create(top_pos, btm_pos)
	ray_query.collide_with_areas = true
	# shoot
	var ray_result: Dictionary = space.intersect_ray(ray_query)
	return self._handle_ray(ray_result)
	
func _handle_ray(ray_result: Dictionary) -> TerrainRaycastResult:
	var collider: Node3D = ray_result.get("collider") as Node3D
	var result: TerrainRaycastResult = TerrainRaycastResult.new()
	result.pos = ray_result.get("position")
	if collider:
		if collider is ClickableCollider:
			result.hit_object = collider.get_click_ref()
	return result
