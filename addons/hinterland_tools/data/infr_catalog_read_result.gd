@tool
## Validated infrastructure JSON read, including missing-file state and untouched source records.
class_name InfrCatalogReadResult extends RefCounted

var error: String = ""
var exists: bool = false
var records: Array[Dictionary] = []
var ok: bool:
	get: return error.is_empty()

static func from_json(data: Variant) -> InfrCatalogReadResult:
	var result := InfrCatalogReadResult.new()
	result.error = InfrLineValidator.validate_records(data)
	if result.ok:
		result.records.assign(data)
		result.exists = true
	return result

static func read(path: String) -> InfrCatalogReadResult:
	var result := InfrCatalogReadResult.new()
	if path.is_empty():
		result.error = "The open world has no valid map key."
		return result
	if not FileAccess.file_exists(path):
		return result
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.error = "Cannot read %s: %s" % [path, error_string(FileAccess.get_open_error())]
		return result
	var parser := JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		result.error = "Invalid JSON in %s, line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()]
		return result
	result = from_json(parser.data)
	if not result.ok:
		result.error = "%s: %s" % [path, result.error]
	return result
