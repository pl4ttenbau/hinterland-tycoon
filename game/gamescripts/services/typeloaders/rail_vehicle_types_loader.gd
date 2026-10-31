@icon("uid://r84qkk5fcxhq")
class_name RailVehicleTypesLoader extends AbstractGameTypeLoader

const CATALOG_PATH = "res://game/jsondata/rail_vehicle_types.json"

## Override for alternate rail catalogs or isolated tests.
var catalog_path: String = CATALOG_PATH

func load_types() -> Error:
	var file: FileAccess = FileAccess.open(self.catalog_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open rail vehicle catalog: %s" % self.catalog_path)
		return FileAccess.get_open_error()
	var parser := JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	if error != OK:
		push_error("Invalid rail vehicle JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return error
	if not parser.data is Array:
		push_error("Rail vehicle catalog must contain an array")
		return ERR_INVALID_DATA
	var definitions: Array[VehicleTypeData] = []
	for entry: Variant in parser.data:
		if not entry is Dictionary:
			return ERR_INVALID_DATA
		var definition: RailVehicleTypeData = VehicleMapper.rail_type_dict_to_class(entry)
		if definition == null:
			return ERR_INVALID_DATA
		definitions.append(definition)
	error = validate_keys(definitions)
	if error != OK:
		return error
	# Validate everything before appending to the shared vehicle catalog. A future
	# RoadVehicleTypesLoader can register its own definitions without overwriting rail.
	for definition: VehicleTypeData in definitions:
		if GameTypes.vehicle_types_dict.has(definition.key):
			push_error("Vehicle key is already registered: %s" % definition.key)
			return ERR_ALREADY_EXISTS
	for definition: VehicleTypeData in definitions:
		GameTypes.vehicle_types.append(definition)
		GameTypes.vehicle_types_dict[definition.key] = definition
	self.loading_finished.emit()
	return OK
