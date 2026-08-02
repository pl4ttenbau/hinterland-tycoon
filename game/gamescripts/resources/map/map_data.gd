class_name MapData extends Resource

const WORLDS_FOLDER = "res://world/"

## name of folder in "res://world
@export var key: String

@export var name: String

## NORTHERN_GERMANY | SOUTHERN_GERMANY | POLAND | RUSSIA
@export var loc: String

@export var start_pos_xz: Vector2

@export var size_and_pos: MapSizeAndPosData

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
	# optional: pos & size (raster, gps)
	if _dict.has("sizeAndPos"):
		inst.size_and_pos = MapSizeAndPosData.of_dict(_dict.get("sizeAndPos"))
	# optional: flags
	if _dict.has("spawnVehicles"):
		inst.spawn_vehicles = _dict.get("spawnVehicles")
	return inst

#region Load From File
static func parse(map_key: String) -> MapData:
	var map_info_file_path := WORLDS_FOLDER + "/" + map_key + "/jsondata/mapinfo.json"
	var map_dict: Dictionary = get_map_info_dict(map_info_file_path)
	if !map_dict || map_dict.has("error"):
		return null
	return MapData.of_dict(map_dict)

static func get_map_info_dict(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if !file: return {"error": "Cant load map"}
	var content_str: String = file.get_as_text()
	return JSON.parse_string(content_str)
#endregion

#region Map File Paths
static func build_scene_file_path(map_key: String) -> String:
	return WORLDS_FOLDER + map_key + "/mapscenes/" + "world_" + map_key + ".tscn"

func get_scene_file_path() -> String:
	return MapData.build_scene_file_path(self.key)

func get_preview_image_path() -> String:
	return WORLDS_FOLDER + self.key + "/preview.png"

static func build_map_data_json_file_path(map_key: String) -> String:
	return WORLDS_FOLDER + map_key + "/jsondata/mapinfo.json"
#endregion 
