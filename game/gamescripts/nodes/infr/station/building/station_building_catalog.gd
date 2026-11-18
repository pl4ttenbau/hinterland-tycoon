## Loads the scene pair for a station building used by gameplay construction.
class_name StationBuildingCatalog extends RefCounted

const PATH := "res://game/jsondata/station_buildings.json"

var building_scene: PackedScene
var preview_scene: PackedScene


static func rail_platform(station_type: String = "STATION_PASS") -> StationBuildingCatalog:
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not catalog is Dictionary:
		return null
	var entry: Variant = catalog.get(station_type)
	if not entry is Dictionary or not entry.get("construction") is Dictionary:
		return null
	var scenes := StationBuildingCatalog.new()
	scenes.building_scene = _load_scene(entry.get("scene_path"))
	scenes.preview_scene = _load_scene(entry.construction.get("preview_scene_path"))
	return scenes if scenes.building_scene != null and scenes.preview_scene != null else null


static func _load_scene(path: Variant) -> PackedScene:
	if not path is String or not path.begins_with("res://") or not ResourceLoader.exists(path, "PackedScene"):
		return null
	return load(path) as PackedScene
