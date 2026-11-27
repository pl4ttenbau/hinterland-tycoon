@tool
class_name IndustryBuildingType extends Resource

@export var key: String

@export var display_name: String

@export_file("*.tscn") var scene_path: String

## A negative cost marks a building without construction configured.
@export var construction_cost: int = -1
@export_file("*.tscn") var preview_scene_path: String
@export var construction_materials: Array[TransformedGood] = []

## Optional picker image: preview.png in the building scene's folder.
func get_preview_img_path() -> String:
	return scene_path.get_base_dir().path_join("preview.png")
