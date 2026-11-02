@tool
## One viewport selection hit, with its semantic target and screen/ray distances.
class_name EditorPickHit extends RefCounted

var target: Node
var label: String = ""
var world_position: Vector3
var depth: float
var screen_distance: float

static func at_position(position: Vector3, ray_depth: float, pixel_distance: float) -> EditorPickHit:
	var hit := EditorPickHit.new()
	hit.world_position = position
	hit.depth = ray_depth
	hit.screen_distance = pixel_distance
	return hit
