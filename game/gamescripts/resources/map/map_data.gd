class_name MapData extends Resource

const MAPS_FOLDER = "res://world/"

## name of folder in "res://world
@export var key: String

@export var name: String

## NORTHERN_GERMANY | SOUTHERN_GERMANY | POLAND | RUSSIA
@export var loc: String

@export var start_pos_xz: Vector2

# Flags
@export var spawn_vehicles: bool

static func of_dict(_dict: Dictionary) -> MapData:
	var inst: MapData = MapData.new()
	inst.key = _dict.get("key")
	inst.name = _dict.get("name")
	inst.loc = _dict.get("loc")
	# optional: start pos
	if _dict.has("startPos") && _dict.get("startPos") != null:
		var pos_xz_arr: Array = _dict.get("startPos")
		inst.start_pos_xz = Vector2(pos_xz_arr[0], pos_xz_arr[1])
	# optional: flags
	if _dict.has("spawnVehicles"):
		inst.spawn_vehicles = _dict.get("spawnVehicles")
	return inst

func get_scene_file_path() -> String:
	return MAPS_FOLDER + self.key + "/mapscenes/" + "terrain_" + self.key + ".tscn"
