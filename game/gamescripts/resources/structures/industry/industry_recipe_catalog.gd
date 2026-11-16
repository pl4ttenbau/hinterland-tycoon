@tool
class_name IndustryRecipeCatalog extends RefCounted

const BUILDINGS_PATH := "res://game/jsondata/industry_buildings.json"
const INDUSTRIES_PATH := "res://game/jsondata/industries.json"
const INT64_UPPER_BOUND: float = 9223372036854775808.0

var buildings: Dictionary[String, IndustryBuildingType] = {}
var industries: Array[IndustryType] = []
var problem: String


## Both the map editor and the game resolve building keys with the same reader.
## Publish the definitions only after the complete pair has been parsed.
func read(buildings_path: String = BUILDINGS_PATH, industries_path: String = INDUSTRIES_PATH) -> Error:
	var error: Error = read_buildings(buildings_path)
	if error != OK:
		return error

	var rows: Array = _read_rows(industries_path)
	if not problem.is_empty():
		buildings.clear()
		return ERR_INVALID_DATA
	var definitions: Array[IndustryType] = []
	var seen: Dictionary[String, bool] = {}
	for index: int in rows.size():
		var row: Variant = rows[index]
		var definition: IndustryType = _read_industry(row) if row is Dictionary else null
		if definition == null or seen.has(definition.key):
			buildings.clear()
			var label: Variant = row.get("key", index + 1) if row is Dictionary else index + 1
			return _fail(industries_path, "Invalid or duplicate recipe %s." % label)
		seen[definition.key] = true
		definitions.append(definition)
	industries = definitions
	return OK


## Standalone building scenes can validate their construction settings in the editor.
func read_buildings(path: String = BUILDINGS_PATH) -> Error:
	buildings.clear()
	industries.clear()
	problem = ""
	var rows: Array = _read_rows(path)
	if not problem.is_empty():
		return ERR_INVALID_DATA
	var definitions: Dictionary[String, IndustryBuildingType] = {}
	for index: int in rows.size():
		var row: Variant = rows[index]
		var definition: IndustryBuildingType = _read_building(row) if row is Dictionary else null
		if definition == null or definitions.has(definition.key):
			var label: Variant = row.get("key", index + 1) if row is Dictionary else index + 1
			return _fail(path, "Invalid or duplicate building %s." % label)
		definitions[definition.key] = definition
	buildings = definitions
	return OK


## The runtime goods registry is available before either industry catalog is published.
func validate_goods(goods: Dictionary) -> Error:
	for definition: IndustryBuildingType in buildings.values():
		for material: TransformedGood in definition.construction_materials:
			var good: BaseGoodsType = goods.get(material.res_key)
			if good == null or not good.is_cargo():
				return _fail(BUILDINGS_PATH, "%s has invalid construction material %s." % [definition.key, material.res_key])
	for definition: IndustryType in industries:
		for amount: TransformedGood in definition.requires + definition.produces:
			var good: BaseGoodsType = goods.get(amount.res_key)
			if good == null or (good.is_passenger() and amount.res_modifier != floorf(amount.res_modifier)):
				return _fail(INDUSTRIES_PATH, "%s has invalid recipe quantity for %s." % [definition.key, amount.res_key])
	return OK

func _read_rows(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail(path, "Could not open the catalog.")
		return []
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		_fail(path, "Line %d. %s" % [json.get_error_line(), json.get_error_message()])
		return []
	if not json.data is Array or json.data.is_empty():
		_fail(path, "Expected a nonempty array of definitions.")
		return []
	return json.data


func _read_building(row: Dictionary) -> IndustryBuildingType:
	if not _has_identity(row) or not _is_scene_path(row.get("scene_path")) or not row.has("construction"):
		return null
	var definition := IndustryBuildingType.new()
	definition.key = row.key
	definition.display_name = row.display_name
	definition.scene_path = row.scene_path

	var construction: Variant = row.construction
	if construction == null:
		return definition
	if not construction is Dictionary or not _is_nonnegative_integer(construction.get("cost")) \
			or not _is_scene_path(construction.get("preview_scene_path")):
		return null
	if not _read_amounts(construction.get("materials"), definition.construction_materials):
		return null
	definition.construction_cost = int(construction.cost)
	definition.preview_scene_path = construction.preview_scene_path
	return definition


func _read_industry(row: Dictionary) -> IndustryType:
	if not _has_identity(row) or not _is_nonnegative_integer(row.get("workers")):
		return null
	var building_key: Variant = row.get("building_key")
	if not building_key is String or not buildings.has(building_key):
		return null
	var definition := IndustryType.new(row.key, row.display_name, buildings[building_key], int(row.workers))
	if not _read_amounts(row.get("requires"), definition.requires) \
			or not _read_amounts(row.get("produces"), definition.produces):
		return null
	if definition.requires.is_empty() and definition.produces.is_empty():
		return null
	return definition


func _read_amounts(rows: Variant, amounts: Array[TransformedGood]) -> bool:
	if not rows is Array:
		return false
	for row: Variant in rows:
		if not row is Dictionary or not _is_nonempty_string(row.get("good")):
			return false
		var amount: Variant = row.get("amount")
		if not _is_number(amount) or float(amount) <= 0.0:
			return false
		amounts.append(TransformedGood.new(row.good, float(amount)))
	return true


func _fail(path: String, message: String) -> Error:
	problem = "%s: %s" % [path, message]
	return ERR_INVALID_DATA


static func _has_identity(row: Dictionary) -> bool:
	return _is_nonempty_string(row.get("key")) and _is_nonempty_string(row.get("display_name"))


static func _is_nonempty_string(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()


static func _is_scene_path(value: Variant) -> bool:
	return value is String and value.begins_with("res://") and value.ends_with(".tscn") \
		and ResourceLoader.exists(value, "PackedScene")


static func _is_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _is_nonnegative_integer(value: Variant) -> bool:
	return _is_number(value) and float(value) >= 0.0 and float(value) < INT64_UPPER_BOUND \
		and float(value) == floorf(float(value))
