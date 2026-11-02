extends RefCounted
func _mcp_eval(tree, node):
	GlobalState.selected_map_name = "mpsb"
	MapListLoader.select_map()
	if is_instance_valid(UiState.main_menu_root):
		UiState.main_menu_root.close()
	var world: Node = GlobalState.world_container
	var terrain = world.terrain
	var camera := Camera3D.new()
	camera.name = "ShadowDiagnosticCamera"
	camera.fov = 60.0
	camera.far = 750.0
	world.add_child(camera)
	camera.global_position = Vector3(2550, terrain.data.get_height(Vector3(2550, 0, 2450)) + 2.5, 2450)
	camera.look_at(camera.global_position + Vector3(1, -0.05, 0))
	camera.make_current()
	terrain.set_camera(camera)
	return str(camera.global_position)
