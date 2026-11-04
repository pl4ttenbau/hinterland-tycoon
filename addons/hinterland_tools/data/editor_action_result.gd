@tool
## Result of an editor load/save action: success, failure text, item count and backup path.
class_name EditorActionResult extends RefCounted

var error: String = ""
var count: int = 0
var backup: String = ""
var ok: bool:
	get: return error.is_empty()

static func success(item_count: int = 0, backup_path: String = "") -> EditorActionResult:
	var result := EditorActionResult.new()
	result.count = item_count
	result.backup = backup_path
	return result

static func failure(message: String) -> EditorActionResult:
	var result := EditorActionResult.new()
	result.error = message if not message.is_empty() else "Editor action failed."
	return result
