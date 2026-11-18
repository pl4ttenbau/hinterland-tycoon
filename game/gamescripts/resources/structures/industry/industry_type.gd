@tool
@icon("res://assets/icons/icon_industry_white.png")
class_name IndustryType extends Resource

@export var key: String
@export var name: String
@export var building: IndustryBuildingType
@export var workers: int
@export var requires: Array[TransformedGood] = []
@export var produces: Array[TransformedGood] = []


func _init(_key: String = "", _name: String = "", _building: IndustryBuildingType = null,
		_workers: int = 0, requires_rows: Array[String] = [], produces_rows: Array[String] = []) -> void:
	key = _key
	name = _name
	building = _building
	workers = _workers
	for row: String in requires_rows:
		requires.append(TransformedGood.from_string(row))
	for row: String in produces_rows:
		produces.append(TransformedGood.from_string(row))
