## What the build picker closed with: either a building to place with a
## terrain preview, or a placement tool to start through ActionHandler.
class_name BuildChoice extends RefCounted

## The placement tool to start; NONE for a building.
var tool: Enums.BuildToolChoice = Enums.BuildToolChoice.NONE
var definition: IndustryBuildingType
var building: PackedScene
var preview: PackedScene
## Local transform of the building's visual model, applied to the preview.
var model_transform := Transform3D.IDENTITY


static func of_building(building_type: IndustryBuildingType, building_scene: PackedScene,
		preview_scene: PackedScene, transform: Transform3D) -> BuildChoice:
	var choice := BuildChoice.new()
	choice.definition = building_type
	choice.building = building_scene
	choice.preview = preview_scene
	choice.model_transform = transform
	return choice


static func of_tool(build_tool: Enums.BuildToolChoice) -> BuildChoice:
	var choice := BuildChoice.new()
	choice.tool = build_tool
	return choice


func is_tool() -> bool:
	return tool != Enums.BuildToolChoice.NONE
