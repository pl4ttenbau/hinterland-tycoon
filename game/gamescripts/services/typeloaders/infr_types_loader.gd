class_name InfrTypesLoader extends AbstractGameTypeLoader

const ROAD_CATALOG_PATH := "res://game/jsondata/road_types.json"
const DEFAULT_ROAD_TYPE := "rural_road"
const RAIL_CATALOG_PATH := "res://game/jsondata/rail_types.json"
## Unknown gauges render and measure as standard gauge, as before the catalog existed.
const DEFAULT_RAIL_TYPE := "NORMAL_GAUGE"

func load_types() -> Error:
	var road_definitions: Dictionary[String, RoadType] = {}
	var error: Error = _load_road_types(road_definitions)
	if error != OK:
		return error
	var rail_definitions: Dictionary[String, RailType] = {}
	error = _load_rail_types(rail_definitions)
	if error != OK:
		return error
	var definitions: Array[InfrType] = make_types(rail_definitions)
	error = validate_keys(definitions)
	if error != OK:
		return error
	GameTypes.infr_types = definitions
	GameTypes.road_types = road_definitions
	GameTypes.rail_types = rail_definitions
	self.loading_finished.emit()
	return OK

## Vehicle catalogs validate their usable_infr subtype against these keys.
static func make_types(rail_definitions: Dictionary[String, RailType]) -> Array[InfrType]:
	var infr_types: Array[InfrType] = []
	for rail_type: RailType in rail_definitions.values():
		infr_types.append(InfrType.new(infr_types.size(), rail_type.key, true, rail_type.scene.resource_path))
	# Legacy road key; road vehicles do not name a road subtype.
	infr_types.append(InfrType.new(infr_types.size(), "RURAL_ROAD", false, ""))
	return infr_types

#region Catalog reading
## Both catalogs are JSON arrays of objects; returns null and reports the reason otherwise.
func _read_catalog(path: String, label: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s type catalog: %s" % [label, path])
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		push_error("Invalid %s type JSON at line %d: %s" % [label, parser.get_error_line(), parser.get_error_message()])
		return null
	if not parser.data is Array:
		push_error("%s type catalog must contain an array" % label.capitalize())
		return null
	return parser.data

static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(value)

## Loads the scene and returns an instance for validation; the caller frees it.
static func _preview_scene(scene_path: Variant) -> Node:
	if not scene_path is String or not ResourceLoader.exists(scene_path, "PackedScene"):
		return null
	var scene := load(scene_path) as PackedScene
	return scene.instantiate() if scene != null else null
#endregion

#region Roads
func _load_road_types(definitions: Dictionary[String, RoadType]) -> Error:
	var entries: Variant = _read_catalog(ROAD_CATALOG_PATH, "road")
	if entries == null:
		return ERR_INVALID_DATA
	for entry: Variant in entries:
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
	var width: Variant = entry.get("drivable_width_metres")
	var height: Variant = entry.get("mesh_height_metres")
	if not key is String or key.strip_edges().is_empty():
		return null
	if not _is_number(width) or width <= 0.0 or not _is_number(height):
		return null
	var preview: Node = _preview_scene(entry.get("scene"))
	if preview == null:
		return null
	var road := preview as RoadWay3D
	var valid_scene := road != null and road.has_mesh_profile()
	preview.free()
	if not valid_scene:
		return null
	var definition := RoadType.new()
	definition.key = key
	definition.scene = load(entry["scene"])
	definition.drivable_width_metres = width
	definition.mesh_height_metres = height
	return definition
#endregion

#region Rails
func _load_rail_types(definitions: Dictionary[String, RailType]) -> Error:
	var entries: Variant = _read_catalog(RAIL_CATALOG_PATH, "rail")
	if entries == null:
		return ERR_INVALID_DATA
	for entry: Variant in entries:
		var definition := _read_rail_type(entry)
		if definition == null or definitions.has(definition.key):
			push_error("Invalid or duplicate rail type: %s" % str(entry))
			return ERR_INVALID_DATA
		definitions[definition.key] = definition
	if not definitions.has(DEFAULT_RAIL_TYPE):
		push_error("Rail type catalog is missing the default type: %s" % DEFAULT_RAIL_TYPE)
		return ERR_INVALID_DATA
	return OK

func _read_rail_type(entry: Variant) -> RailType:
	if not entry is Dictionary:
		return null
	var key: Variant = entry.get("key")
	var gauge: Variant = entry.get("gauge_mm")
	var head_height: Variant = entry.get("rail_head_height_metres")
	# Keys must already be normalized; legacy aliases such as 1067_MM map onto them.
	if not key is String or key.strip_edges().is_empty() or InfrType.normalize_rail_gauge(key) != key:
		return null
	if not _is_number(gauge) or gauge <= 0 or gauge != int(gauge):
		return null
	if not _is_number(head_height) or head_height < 0.0:
		return null
	var preview: Node = _preview_scene(entry.get("scene"))
	if preview == null:
		return null
	var valid_scene: bool = preview is RailTrack3D
	preview.free()
	if not valid_scene:
		return null
	var definition := RailType.new()
	definition.key = key
	definition.scene = load(entry["scene"])
	definition.gauge_mm = int(gauge)
	definition.rail_head_height_metres = head_height
	return definition
#endregion
