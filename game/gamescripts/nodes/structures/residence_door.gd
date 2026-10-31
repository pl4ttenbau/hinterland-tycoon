@tool
@icon("res://assets/icons/nodes_3d/icon_residence_door.svg")
class_name ResidenceDoor extends Marker3D

## Place at foot level, with local -Z pointing out of the doorway.
## The arrow's flat tail (non-pointed end) marks the actual door exit.
## Future road connections must use that tail, not the marker origin, mesh center,
## or arrow tip. The tip only indicates the outward direction.

const ARROW_MESH: Mesh = preload("res://assets/meshes/markers/arrow/fork_arrow.obj")

func _enter_tree() -> void:
	if not Engine.is_editor_hint() or has_node("_DirectionArrow"):
		return
	var arrow := MeshInstance3D.new()
	arrow.name = "_DirectionArrow"
	arrow.mesh = ARROW_MESH
	arrow.scale = Vector3.ONE * 0.8
	# The switch mesh sits above its origin; place its underside just above feet.
	arrow.position.y = 0.08 - ARROW_MESH.get_aabb().position.y * 0.8
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fc7f7f")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.render_priority = 127
	arrow.material_override = material
	# No owner: this is an editor preview, never serialized into house scenes.
	add_child(arrow)
