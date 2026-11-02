@tool
class_name InfrJsonFormatter extends RefCounted

const JSON_LINE_WIDTH: int = 120

static func format_json(value: Variant, depth: int = 0, prefix_width: int = 0, position: bool = false) -> String:
	# Serialize structure, not text replacements: names or metadata containing
	# JSON-looking strings must remain untouched. Only numeric arrays are compacted.
	if value is Dictionary:
		return _format_object(value, depth)
	if value is Array:
		return _format_array(value, depth, prefix_width, position)
	return JSON.stringify(value, "", false, true)

static func _format_object(value: Dictionary, depth: int) -> String:
	if value.is_empty():
		return "{}"
	var indent: String = "\t".repeat(depth)
	var child_indent: String = indent + "\t"
	var fields: PackedStringArray = []
	for key: Variant in value:
		var label: String = JSON.stringify(str(key)) + ": "
		var width: int = (depth + 1) * 4 + label.length()
		fields.append(child_indent + label + format_json(value[key], depth + 1, width, str(key) == "pos"))
	return "{\n" + ",\n".join(fields) + "\n" + indent + "}"

static func _format_array(value: Array, depth: int, prefix_width: int, position: bool) -> String:
	if value.is_empty():
		return "[]"
	var indent: String = "\t".repeat(depth)
	var child_indent: String = indent + "\t"
	var numeric: bool = true
	for element: Variant in value:
		if not (element is int or element is float):
			numeric = false
			break
	var elements: PackedStringArray = []
	for element: Variant in value:
		if numeric:
			elements.append(position_text(float(element)) if position and value.size() == 3 else JSON.stringify(element, "", false, true))
		else:
			elements.append(format_json(element, depth + 1, (depth + 1) * 4))
	if numeric:
		var inline: String = "[" + ", ".join(elements) + "]"
		# Count tabs as four columns and reserve a column for a trailing comma.
		if prefix_width + inline.length() + 1 <= JSON_LINE_WIDTH:
			return inline
	return "[\n" + child_indent + (",\n" + child_indent).join(elements) + "\n" + indent + "]"

static func position_text(value: float) -> String:
	# Avoid "-0.00" for tiny negative coordinates. Formatting supplies normal
	# rounding AND trailing zeros; snapping alone cannot retain those zeros in JSON.
	var rounded: float = roundf(value * 100.0) / 100.0
	return "%.2f" % (0.0 if rounded == 0.0 else rounded)

static func round_positions(records: Array) -> void:
	for record: Dictionary in records:
		for point: Dictionary in record.points:
			for axis: int in range(3):
				point.pos[axis] = float(position_text(point.pos[axis]))
