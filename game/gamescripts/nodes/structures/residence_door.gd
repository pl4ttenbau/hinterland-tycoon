@tool
@icon("res://assets/icons/nodes_3d/icon_residence_door.svg")
class_name ResidenceDoor extends Marker3D

## Place at foot level, with local -Z pointing out of the doorway.
## The arrow's flat tail (non-pointed end) marks the actual door exit.
## Road connections must use that tail, not the marker origin, mesh center,
## or arrow tip. The tip only indicates the outward direction.

const ARROW_MESH: Mesh = preload("res://assets/meshes/markers/arrow/fork_arrow.obj")

func get_arrow_transform() -> Transform3D:
	var bottom: float = ARROW_MESH.get_aabb().position.y
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.8), Vector3(0, 0.08 - bottom * 0.8, 0))

## World-space center of the flat tail face, matching the editor preview exactly.
func get_exit_position() -> Vector3:
	var bounds: AABB = ARROW_MESH.get_aabb()
	var tail: Vector3 = bounds.position + Vector3(bounds.size.x * 0.5, bounds.size.y * 0.5, bounds.size.z)
	return to_global(get_arrow_transform() * tail)

func _enter_tree() -> void:
	if not Engine.is_editor_hint() or has_node("_DirectionArrow"):
		return
	var arrow := MeshInstance3D.new()
	arrow.name = "_DirectionArrow"
	arrow.mesh = ARROW_MESH
	arrow.transform = get_arrow_transform()
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arrow.visibility_range_end = 50.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("fc7f7f")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.render_priority = 127
	arrow.material_override = material
	# No owner: this is an editor preview, never serialized into house scenes.
	add_child(arrow)
