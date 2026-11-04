@tool
class_name ObjectSelectedTool extends RefCounted

var pickers: Array[EditorObjectPicker] = []

func _init() -> void:
	register_picker(InfrLinePicker.new())

## Town/industry pickers can register the same get_hits(world, camera, mouse,
## max_depth) contract later, using marker distance, colliders or bounds as needed.
## Every hit supplies target, world_position, depth and screen_distance.
func register_picker(picker: EditorObjectPicker) -> void:
	if picker not in pickers:
		pickers.append(picker)

func pick(world: Node, camera: Camera3D, mouse: Vector2, max_depth: float = INF) -> EditorPickHit:
	var best: EditorPickHit
	for picker: EditorObjectPicker in pickers:
		for hit: EditorPickHit in picker.get_hits(world, camera, mouse, max_depth):
			if not is_instance_valid(hit.target):
				continue
			# Resolve objects within the same two-pixel band by depth, so nearly
			# overlapping lines favor the front one. Other pickers share this rule.
			var band: int = floori(hit.screen_distance / 2.0)
			if best == null or band < floori(best.screen_distance / 2.0) or (band == floori(best.screen_distance / 2.0) and hit.depth < best.depth):
				best = hit
	return best
