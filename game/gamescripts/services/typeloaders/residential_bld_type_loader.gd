class_name ResidentialBldTypeLoader extends AbstractGameTypeLoader

const CATALOG_PATH = "res://game/jsondata/residence_types.json"

## Override for alternate residence catalogs or isolated tests.
var catalog_path: String = CATALOG_PATH

func load_types() -> Error:
	var file: FileAccess = FileAccess.open(self.catalog_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open residence catalog: %s" % self.catalog_path)
		return FileAccess.get_open_error()
	var parser := JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	if error != OK:
		push_error("Invalid residence JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return error
	if not parser.data is Array:
		push_error("Residence catalog must contain an array")
		return ERR_INVALID_DATA
	var definitions: Array[ResBldType] = []
	for entry: Variant in parser.data:
		if not entry is Dictionary:
			push_error("Residence catalog entries must be objects")
			return ERR_INVALID_DATA
		var definition: ResBldType = _definition_from_dict(entry)
		if definition == null:
			return ERR_INVALID_DATA
		definitions.append(definition)
	error = validate_keys(definitions)
	if error != OK:
		return error
	# Publish only after the complete catalog has passed validation.
	var store := ResBldTypeStore.new()
	for definition: ResBldType in definitions:
		store.add(definition)
	GameTypes.res_bld_type_store = store
	self.loading_finished.emit()
	return OK

static func _definition_from_dict(data: Dictionary) -> ResBldType:
	for field: String in ["key", "name", "scene_path"]:
		if not data.get(field) is String or data[field].strip_edges().is_empty():
			push_error("Residence definition requires a nonempty %s" % field)
			return null
	var scene_path: String = data["scene_path"]
	if not scene_path.begins_with("res://") or not scene_path.ends_with(".tscn"):
		push_error("Residence %s requires a res:// scene path ending in .tscn" % data["key"])
		return null
	var pops: Variant = data.get("pops")
	if not pops is Array or pops.size() != 2:
		push_error("Residence %s requires two population counts" % data["key"])
		return null
	for count: Variant in pops:
		if (typeof(count) != TYPE_INT and typeof(count) != TYPE_FLOAT) \
				or not is_finite(float(count)) or count < 0 or int(count) != count:
			push_error("Residence %s requires nonnegative integer population counts" % data["key"])
			return null
	if not data.get("block_auto_placement", false) is bool:
		push_error("Residence %s requires a boolean block_auto_placement" % data["key"])
		return null
	var theme_names: Variant = data.get("themes", [])
	if not theme_names is Array:
		push_error("Residence %s requires an array of theme names" % data["key"])
		return null
	var themes: Array[Enums.Location] = []
	for theme_name: Variant in theme_names:
		if not theme_name is String or not Enums.Location.has(theme_name):
			push_error("Residence %s has an unknown theme: %s" % [data["key"], theme_name])
			return null
		var theme: Enums.Location = Enums.Location[theme_name]
		if themes.has(theme):
			push_error("Residence %s contains a duplicate theme: %s" % [data["key"], theme_name])
			return null
		themes.append(theme)
	var definition := ResBldType.new(data["key"], data["name"], int(pops[0]), data.get("block_auto_placement", false))
	definition.pops = [int(pops[0]), int(pops[1])]
	definition.scene_path = scene_path
	definition.themes = themes
	return definition

func get_rnd() -> ResBldType:
	return GameTypes.res_bld_type_store.get_random()
