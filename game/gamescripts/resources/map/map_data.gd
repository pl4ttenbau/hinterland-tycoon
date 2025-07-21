class_name MapData extends Resource

const MAPS_FOLDER = "res://world/"

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

func get_scene_file_path() -> String:
	return MAPS_FOLDER + self.key + "/mapscenes/" + "terrain_" + self.key + ".tscn"
