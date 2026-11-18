@tool
## Resting wheel hubs share this centre height and longitudinal position.
## The track width measures the distance between the left and right hubs.
@icon("res://assets/icons/nodes_3d/icon_road_vehicle_axle.svg")
class_name RoadVehicleAxle3D extends Marker3D

@export_range(0.01, 10.0, 0.01, "or_greater", "suffix:m") var track_width: float = 1.6:
	set(value):
		track_width = value
		if Engine.is_editor_hint() and is_inside_tree():
			update_gizmos()
@export_range(0.01, 3.0, 0.01, "or_greater", "suffix:m") var wheel_radius: float = 0.4:
	set(value):
		wheel_radius = value
		if Engine.is_editor_hint() and is_inside_tree():
			update_gizmos()

## The same local endpoints drive the editor gizmo and wheel placement.
func wheel_centres() -> PackedVector3Array:
	var half_track: float = track_width * 0.5
	return PackedVector3Array([Vector3(-half_track, 0, 0), Vector3(half_track, 0, 0)])
