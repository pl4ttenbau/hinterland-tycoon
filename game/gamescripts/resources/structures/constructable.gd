@tool
@icon("res://assets/icons/icon_build_white.png")
class_name Constructable extends Node

## Optional direct child of the building. The preview copies its local transform.
@export var visual_model: BuildingMesh3D

## Authored collision shape used for overlap checks before the building enters the world.
@export var placement_collision_shape: CollisionShape3D:
	set(value):
		placement_collision_shape = value
		update_configuration_warnings()


## Find the building's own component among its direct children.
static func find_on(building: Node) -> Constructable:
	for child: Node in building.get_children():
		if child is Constructable:
			return child
	return null


static func missing_warning(building: Node) -> PackedStringArray:
	if find_on(building) == null:
		return ["Add a Constructable child to configure placement geometry."]
	return []


func _get_configuration_warnings() -> PackedStringArray:
	if placement_collision_shape == null or placement_collision_shape.shape == null:
		return ["Assign a collision shape for construction overlap checks."]
	return []
