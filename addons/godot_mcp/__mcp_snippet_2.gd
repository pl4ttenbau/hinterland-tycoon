extends RefCounted
func _mcp_eval(tree, node):
	GlobalState.world_container.get_node("DayEnvironment/DirectionalLight3D").light_angular_distance = 0.0
	return "Filtered shadows, no PCSS"
