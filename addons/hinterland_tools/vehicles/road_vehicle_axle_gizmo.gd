@tool
extends EditorNode3DGizmoPlugin

const TYRE_SEGMENTS: int = 32

func _init() -> void:
	create_material("axle", Color(1.0, 0.7, 0.2), false, true)

func _get_gizmo_name() -> String:
	return "Road Vehicle Axles"

func _has_gizmo(node: Node3D) -> bool:
	return node is RoadVehicleAxle3D

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var axle := gizmo.get_node_3d() as RoadVehicleAxle3D
	var centres: PackedVector3Array = axle.wheel_centres()
	var lines := centres.duplicate()
	for centre: Vector3 in centres:
		lines.append(centre - Vector3.UP * 0.12)
		lines.append(centre + Vector3.UP * 0.12)
		_append_tyre_circle(lines, centre, axle.wheel_radius)
	gizmo.add_lines(lines, get_material("axle", gizmo))
	gizmo.add_collision_segments(lines)

## The wheel turns about the axle's X axis, so the tyre outline lies in YZ.
func _append_tyre_circle(lines: PackedVector3Array, centre: Vector3, radius: float) -> void:
	var previous: Vector3 = centre + Vector3.UP * radius
	for step: int in range(1, TYRE_SEGMENTS + 1):
		var angle: float = TAU * float(step) / TYRE_SEGMENTS
		var point: Vector3 = centre + Vector3(0, cos(angle), sin(angle)) * radius
		lines.append(previous)
		lines.append(point)
		previous = point
