extends RefCounted
func _mcp_eval(tree, node):
	GlobalState.world_container.terrain.material.output_normal_map = false
	return "No texture normal mapping"
