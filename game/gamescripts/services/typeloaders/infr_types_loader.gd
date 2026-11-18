class_name InfrTypesLoader extends AbstractGameTypeLoader

const ROAD_CATALOG_PATH := "res://game/jsondata/road_types.json"
const DEFAULT_ROAD_TYPE := "rural_road"

func load_types() -> Error:
	var definitions: Array[InfrType] = self.make_types()
	var error: Error = validate_keys(definitions)
	if error != OK:
		return error
	var road_definitions: Dictionary[String, RoadType] = {}
	error = _load_road_types(road_definitions)
	if error != OK:
		return error
	GameTypes.infr_types = definitions
	GameTypes.road_types = road_definitions
	self.loading_finished.emit()
	return OK

static func make_types() -> Array[InfrType]:
	var infr_types: Array[InfrType] = []
	# create objects and append
	infr_types.append(InfrType.new(0, "750_MM", true, "res://scenes/subscenes/infr/rail_path_mesh_3d.tscn"))
	infr_types.append(InfrType.new(1, "NORMAL_GAUGE", true, "res://scenes/subscenes/infr/rail_path_mesh_3d.tscn"))
	infr_types.append(InfrType.new(2, "RURAL_ROAD", false, "res://scenes/subscenes/infr/road_path_mesh_3d.tscn"))
	infr_types.append(InfrType.new(3, InfrType.GAUGE_1000_MM, true, RailTrack3D.SCENE_PATH_1000MM))
	
	return infr_types

func _load_road_types(definitions: Dictionary[String, RoadType]) -> Error:
	var file := FileAccess.open(ROAD_CATALOG_PATH, FileAccess.READ)
	if file == null:
		push_error("Cannot open road type catalog: %s" % ROAD_CATALOG_PATH)
		return FileAccess.get_open_error()
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	if error != OK:
		push_error("Invalid road type JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return error
	if not parser.data is Array:
		push_error("Road type catalog must contain an array")
		return ERR_INVALID_DATA
	for entry: Variant in parser.data:
		var definition := _read_road_type(entry)
		if definition == null or definitions.has(definition.key):
			push_error("Invalid or duplicate road type: %s" % str(entry))
			return ERR_INVALID_DATA
		definitions[definition.key] = definition
	if not definitions.has(DEFAULT_ROAD_TYPE):
		push_error("Road type catalog is missing the default type: %s" % DEFAULT_ROAD_TYPE)
		return ERR_INVALID_DATA
	return OK

func _read_road_type(entry: Variant) -> RoadType:
	if not entry is Dictionary:
		return null
	var key: Variant = entry.get("key")
	var scene_path: Variant = entry.get("scene")
	var width: Variant = entry.get("drivable_width_metres")
	var height: Variant = entry.get("mesh_height_metres")
	if not key is String or key.strip_edges().is_empty() or not scene_path is String:
		return null
	if not (width is float or width is int) or not is_finite(width) or width <= 0.0:
		return null
	if not (height is float or height is int) or not is_finite(height):
		return null
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return null
	var scene := load(scene_path) as PackedScene
	if scene == null:
		return null
	var preview := scene.instantiate()
	var road := preview as RoadWay3D
	var valid_scene := road != null and road.has_mesh_profile()
	preview.free()
	if not valid_scene:
		return null
	var definition := RoadType.new()
	definition.key = key
	definition.scene = scene
	definition.drivable_width_metres = width
	definition.mesh_height_metres = height
	return definition
