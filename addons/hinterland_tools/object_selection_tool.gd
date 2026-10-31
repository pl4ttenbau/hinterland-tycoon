@tool
extends RefCounted

var pickers: Array[RefCounted] = []

func _init() -> void:
	register_picker(preload("res://addons/hinterland_tools/infr_line_picker.gd").new())

## Town/industry pickers can register the same get_hits(world, camera, mouse,
## context) contract later, using marker distance, colliders or bounds as needed.
## Every hit supplies target, world_position, depth and screen_distance.
func register_picker(picker: RefCounted) -> void:
	if picker not in pickers:
		pickers.append(picker)

func pick(world: Node, camera: Camera3D, mouse: Vector2, context: Dictionary = {}) -> Dictionary:
	var best: Dictionary = {}
	for picker: RefCounted in pickers:
		for hit: Dictionary in picker.get_hits(world, camera, mouse, context):
			if not is_instance_valid(hit.get("target")):
				continue
			# Resolve objects within the same two-pixel band by depth, so nearly
			# overlapping lines favor the front one. Other pickers share this rule.
			var band: int = floori(hit.screen_distance / 2.0)
			if best.is_empty() or band < floori(best.screen_distance / 2.0) or (band == floori(best.screen_distance / 2.0) and hit.depth < best.depth):
				best = hit
	return best
