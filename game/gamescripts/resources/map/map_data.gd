class_name MapData extends Resource

## name of folder in "res://world
@export var key: String

@export var name: String

## NORTHERN_GERMANY | SOUTHERN_GERMANY | POLAND | RUSSIA
@export var loc: String

static func of_dict(_dict: Dictionary) -> MapData:
	var inst: MapData = MapData.new()
	inst.key = _dict.get("key")
	inst.name = _dict.get("name")
	inst.loc = _dict.get("loc")
	return inst
