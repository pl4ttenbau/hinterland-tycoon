extends RefCounted
func _mcp_eval(tree, node):
	GlobalState.world_container.get_node("DayEnvironment/DirectionalLight3D").directional_shadow_fade_start = 0.5
	return "Earlier shadow fade"
