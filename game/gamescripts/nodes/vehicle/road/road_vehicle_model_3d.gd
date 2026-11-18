@tool
## Authored road vehicle geometry. The scene faces +Z, with +Y up and metre units.
## The chassis lives under a StaticBody3D so the same box is visible in the editor.
@icon("res://assets/icons/nodes_3d/icon_road_vehicle_model.svg")
class_name RoadVehicleModel3D extends Node3D

@export var chassis: CollisionShape3D:
	set(value):
		chassis = value
		if Engine.is_editor_hint() and is_inside_tree():
			update_configuration_warnings()

## Sort from rear to front. The outermost axles set wheelbase, traction and steering.
func get_axles() -> Array[RoadVehicleAxle3D]:
	var axles: Array[RoadVehicleAxle3D] = []
	for child: Node in get_children():
		if child is RoadVehicleAxle3D:
			axles.append(child)
	axles.sort_custom(func(a: RoadVehicleAxle3D, b: RoadVehicleAxle3D) -> bool: return a.position.z < b.position.z)
	return axles

## Call after validation, while the chassis is still in its authored hierarchy.
func get_dimensions() -> Vector3:
	return (chassis.shape as BoxShape3D).size

func get_chassis_transform() -> Transform3D:
	return chassis.get_parent_node_3d().transform * chassis.transform

func configuration_error() -> String:
	if not transform.basis.is_equal_approx(Basis.IDENTITY):
		return "Keep the model root unrotated and at unit scale. Orient the mesh child along +Z."
	if not is_instance_valid(chassis) or not chassis.shape is BoxShape3D or chassis.disabled:
		return "Assign an enabled CollisionShape3D with a BoxShape3D to Chassis."
	var chassis_body: Node = chassis.get_parent()
	if not chassis_body is StaticBody3D or chassis_body.get_parent() != self:
		return "Place the chassis shape under a direct StaticBody3D child of the model."
	var size: Vector3 = get_dimensions()
	if not size.is_finite() or minf(size.x, minf(size.y, size.z)) <= 0:
		return "The chassis box must have positive dimensions."
	if not get_chassis_transform().basis.is_equal_approx(Basis.IDENTITY):
		return "Keep the chassis box unrotated and at unit scale. Edit BoxShape3D.size to resize it."
	var axles: Array[RoadVehicleAxle3D] = get_axles()
	if axles.size() < 2:
		return "Add at least two RoadVehicleAxle3D children."
	for index: int in range(axles.size()):
		var axle: RoadVehicleAxle3D = axles[index]
		if not axle.position.is_finite() or not axle.transform.basis.is_equal_approx(Basis.IDENTITY):
			return "Keep each axle unrotated and at unit scale. Move it to the centre of its wheel hubs."
		if not is_finite(axle.track_width) or axle.track_width <= 0 or not is_finite(axle.wheel_radius) or axle.wheel_radius <= 0:
			return "Each axle requires a positive track width and wheel radius."
		if index > 0 and is_equal_approx(axle.position.z, axles[index - 1].position.z):
			return "Axles must have distinct positions along the model's Z axis."
	return ""

func _get_configuration_warnings() -> PackedStringArray:
	var error: String = configuration_error()
	return PackedStringArray() if error.is_empty() else PackedStringArray([error])
