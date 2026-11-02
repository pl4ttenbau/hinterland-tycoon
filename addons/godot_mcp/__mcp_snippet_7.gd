extends RefCounted
func _mcp_eval(tree, node):
	GlobalState.selected_map_name = "mpsb"
	MapListLoader.select_map()
	if is_instance_valid(UiState.main_menu_root):
		UiState.main_menu_root.close()
	var world: Node = GlobalState.world_container
	var terrain = world.terrain
	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.far = 750.0
	world.add_child(camera)
	camera.global_position = Vector3(2250, terrain.data.get_height(Vector3(2250, 0, 2300)) + 3.0, 2300)
	camera.look_at(camera.global_position + Vector3(0, -0.05, 1))
	camera.make_current()
	terrain.set_camera(camera)
	var sun: DirectionalLight3D = world.get_node("DayEnvironment/DirectionalLight3D")
	sun.light_angular_distance = 0.0
	sun.directional_shadow_fade_start = 0.5
	sun.shadow_bias = 0.15
	sun.shadow_opacity = 0.9
	return "Final conservative shadow settings"
