@tool
class_name IndustryBuildingType extends Resource

@export var key: String

@export var display_name: String

@export_file("*.tscn") var scene_path: String

## A negative cost marks a building without construction configured.
@export var construction_cost: int = -1
@export_file("*.tscn") var preview_scene_path: String
@export var construction_materials: Array[TransformedGood] = []
