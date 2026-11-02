extends RefCounted
func _mcp_eval(tree, node):
	GlobalState.selected_map_name = "mpsb"
	MapListLoader.select_map()
	if is_instance_valid(UiState.main_menu_root):
		UiState.main_menu_root.close()
	var env: Environment = GlobalState.world_container.get_node("DayEnvironment/WorldEnvironment").environment
	return {"exposure": env.tonemap_exposure, "contrast": env.adjustment_contrast, "saturation": env.adjustment_saturation, "adjustments_enabled": env.adjustment_enabled}
