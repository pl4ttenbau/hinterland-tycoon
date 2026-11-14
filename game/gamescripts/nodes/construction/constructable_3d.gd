@tool
class_name Constructable3D extends Node

## Catalog key for industry buildings. Other constructables can supply their own settings.
@export var industry_building_key: String:
	set(value):
		industry_building_key = value
		update_configuration_warnings()

## A visual-only scene shared with the building's live model.
@export var preview_scene: PackedScene:
	set(value):
		preview_scene = value
		update_configuration_warnings()

@export var construction_cost: int = -1:
	set(value):
		construction_cost = value
		update_configuration_warnings()

## Optional direct child of the building. Reuses its local placement and scale.
@export var model: Node3D

## Authored collision shape used for overlap checks before the building enters the world.
@export var placement_shape: CollisionShape3D:
	set(value):
		placement_shape = value
		update_configuration_warnings()


## Look at direct children so an instanced sub-building cannot supply its parent's cost or preview.
static func find_on(building: Node) -> Constructable3D:
	for child: Node in building.get_children():
		if child is Constructable3D:
			return child
	return null


static func missing_warning(building: Node) -> PackedStringArray:
	if find_on(building) == null:
		return ["Add a Constructable3D child to configure the build preview and cost."]
	return []


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var has_preview: bool = preview_scene != null
	var cost: int = construction_cost
	if not industry_building_key.is_empty():
		var catalog := IndustryRecipeCatalog.new()
		if catalog.read_buildings() != OK:
			return PackedStringArray([catalog.problem])
		var definition: IndustryBuildingType = catalog.buildings.get(industry_building_key)
		if definition == null:
			return PackedStringArray(["Unknown industry building key: %s." % industry_building_key])
		has_preview = not definition.preview_scene_path.is_empty()
		cost = definition.construction_cost
	if not has_preview:
		warnings.append("Assign a visual scene for the build preview.")
	if cost < 0:
		warnings.append("Set the construction cost. Use 0 for a free building.")
	if placement_shape == null or placement_shape.shape == null:
		warnings.append("Assign a collision shape for construction overlap checks.")
	return warnings
