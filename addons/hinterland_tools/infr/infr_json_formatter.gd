@tool
class_name InfrJsonFormatter extends RefCounted

const JSON_LINE_WIDTH: int = 120
## Bezier handles (handleIn/handleOut) are written with 3 decimals: millimetres. Auto smoothing computes
## them in full float precision, which only bloats the JSON and its diffs without changing the track.
const HANDLE_KEYS: Array[String] = ["handleIn", "handleOut"]
## Lists of track or road numbers. JSON has no integer type, so after a read they hold floats and would
## be written back as "4.0", while freshly generated lists print "4": one file would mix both styles, and
## every regenerated fork would show up as a diff. These are always written as integers.
const ID_LIST_KEYS: Array[String] = ["connectiveTracks", "connectiveRoads", "autoConnectiveRoads"]

static func format_json(value: Variant, depth: int = 0, prefix_width: int = 0, position: bool = false, handle: bool = false, ids: bool = false) -> String:
	# Serialize structure, not text replacements: names or metadata containing
	# JSON-looking strings must remain untouched. Only numeric arrays are compacted.
	if value is Dictionary:
		return _format_object(value, depth)
	if value is Array:
		return _format_array(value, depth, prefix_width, position, handle, ids)
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
		fields.append(child_indent + label + format_json(value[key], depth + 1, width, str(key) == "pos", HANDLE_KEYS.has(str(key)), ID_LIST_KEYS.has(str(key))))
	return "{\n" + ",\n".join(fields) + "\n" + indent + "}"

static func _format_array(value: Array, depth: int, prefix_width: int, position: bool, handle: bool = false, ids: bool = false) -> String:
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
			if position and value.size() == 3:
				elements.append(position_text(float(element)))
			elif ids and float(element) == floorf(float(element)):
				elements.append(str(int(element)))
			elif handle and value.size() == 3:
				elements.append(handle_text(float(element)))
			else:
				elements.append(JSON.stringify(element, "", false, true))
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

## Handles are written with 3 decimals, trailing zeros dropped, like existing maps ("2.1", "-0.03").
## Rounding the float alone is not enough: JSON would still print binary noise such as 4.123000000000001.
static func handle_text(value: float) -> String:
	var text: String = "%.3f" % value
	if text.begins_with("-") and float(text) == 0.0:
		text = text.substr(1)
	text = text.rstrip("0")
	return text + "0" if text.ends_with(".") else text

static func round_positions(records: Array) -> void:
	for record: Dictionary in records:
		for point: Dictionary in record.points:
			for axis: int in range(3):
				point.pos[axis] = float(position_text(point.pos[axis]))
			## Same values as written, so anything comparing saved geometry sees what the file will contain.
			for key: String in HANDLE_KEYS:
				if point.get(key) is Array and point[key].size() == 3:
					for axis: int in range(3):
						point[key][axis] = float(handle_text(point[key][axis]))
