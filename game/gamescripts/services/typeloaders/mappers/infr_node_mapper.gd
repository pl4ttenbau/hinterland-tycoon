@tool
## JSON point fields shared by rail and road nodes.
class_name InfrNodeMapper extends RefCounted

## Reads curve handles and the dead-end flag from one entry of a track's "points".
static func apply_point_fields(node: AbstractInfrNode, point: Dictionary) -> void:
	if point.has("handleIn"):
		node.handle_in = WorldUtils.vec3_from_float_arr(point.get("handleIn"))
		# Legacy maps stored only handleIn and assumed mirrored handles.
		node.handle_out = -1 * node.handle_in
	# Catmull-Rom smoothing needs independent handle lengths, so handleOut wins when present.
	if point.has("handleOut"):
		node.handle_out = WorldUtils.vec3_from_float_arr(point.get("handleOut"))
	if point.get("end", false) == true:
		node.is_end = true
