extends RefCounted
func _mcp_eval(tree, node):
	GlobalState.world_container.get_node("DayEnvironment/DirectionalLight3D").shadow_caster_mask = 0
	return "No shadow casters"
